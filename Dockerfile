# Dockerfile for Singularity Edge
# Multi-stage build optimized for Elixir releases

ARG ELIXIR_VERSION=1.17.3
ARG ERLANG_VERSION=27.1.2
ARG ALPINE_VERSION=3.20.3

# ====================================
# Stage 1: Build Dependencies
# ====================================
FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS deps

RUN apk add --no-cache \
    git \
    build-base \
    rocksdb \
    rocksdb-dev

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# ====================================
# Stage 2: Build Assets
# ====================================
FROM deps AS assets

RUN apk add --no-cache nodejs npm

WORKDIR /app

# Copy assets
COPY assets assets/
COPY priv priv/

# Install and build assets
RUN cd assets && npm install
COPY config config/
ENV MIX_ENV=prod
RUN mix assets.deploy

# ====================================
# Stage 3: Build Release
# ====================================
FROM deps AS release_build

WORKDIR /app

# Copy compiled deps
COPY --from=deps /app/deps /app/deps
COPY --from=assets /app/priv/static /app/priv/static

# Copy application code
COPY lib lib/
COPY config config/
COPY mix.exs mix.lock ./
COPY priv priv/

# Compile and build release
ENV MIX_ENV=prod
RUN mix compile
RUN mix release

# ====================================
# Stage 4: Runtime
# ====================================
FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    ca-certificates \
    rocksdb

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app
USER app

# Copy release from build stage
COPY --from=release_build --chown=app:app /app/_build/prod/rel/singularity_edge ./

ENV HOME=/app
ENV MIX_ENV=prod
ENV PORT=8080

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1

CMD ["bin/server"]
