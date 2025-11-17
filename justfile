# Singularity Edge - Development Task Runner
# Run `just` to see all available commands

# Default recipe - show interactive command picker
default:
  @just --choose

# ==============================================================================
# SETUP & ENVIRONMENT
# ==============================================================================

# Initial project setup (run once)
init:
  @echo "🚀 Initializing Singularity Edge development environment..."
  @echo "📦 Installing dependencies..."
  mix deps.get
  @echo "🗄️  Setting up database..."
  @just db-ensure
  mix ecto.setup
  @echo "📦 Installing frontend dependencies..."
  cd assets && npm install
  @echo "✅ Setup complete! Run 'just dev' to start developing"

# Clean all build artifacts and caches
clean:
  @echo "🧹 Cleaning build artifacts..."
  mix clean
  rm -rf _build deps .nix-mix .nix-hex .nix-cargo cover
  @echo "✅ Clean complete!"

# Update all dependencies
update:
  @echo "📦 Updating Elixir dependencies..."
  mix deps.update --all
  @echo "📦 Updating frontend dependencies..."
  cd assets && npm update
  @echo "✅ Dependencies updated!"

# ==============================================================================
# DEVELOPMENT WORKFLOW
# ==============================================================================

# Start development server (PostgreSQL + Phoenix)
dev:
  @echo "🚀 Starting development environment..."
  @just db-ensure
  mix phx.server

# Run tests (quick feedback loop)
test *ARGS:
  @just db-ensure
  @echo "🧪 Running tests..."
  MIX_ENV=test mix ecto.create --quiet || true
  MIX_ENV=test mix ecto.migrate --quiet
  MIX_ENV=test mix test {{ARGS}}

# Format all code (Elixir + Nix)
fmt:
  @echo "📝 Formatting code..."
  mix format
  nix fmt
  @echo "✅ Code formatted!"

# Quick pre-commit checks (fast feedback ~30s)
check: fmt
  @echo "🔍 Running quick checks..."
  mix compile --warnings-as-errors
  mix credo --strict
  @echo "✅ Quick checks passed!"

# ==============================================================================
# DATABASE
# ==============================================================================

# Ensure database is running and ready
db-ensure:
  @if ! pg_isready -h localhost -p 5433 > /dev/null 2>&1; then \
    echo "⏳ Starting PostgreSQL with 'devenv up -d'..."; \
    devenv up -d; \
    echo "⏳ Waiting for PostgreSQL to be ready..."; \
    sleep 3; \
    for i in `seq 1 30`; do \
      if pg_isready -h localhost -p 5433 > /dev/null 2>&1; then \
        echo "✅ PostgreSQL is ready"; \
        break; \
      fi; \
      echo "⏳ Still waiting for PostgreSQL..."; \
      sleep 1; \
      if [ $$i -eq 30 ]; then \
        echo "❌ PostgreSQL failed to start after 30 seconds"; \
        exit 1; \
      fi; \
    done; \
  fi

# Check database status
db-status:
  @if pg_isready -h localhost -p 5433 > /dev/null 2>&1; then \
    echo "✅ PostgreSQL is running on port 5433"; \
  else \
    echo "❌ PostgreSQL is not running"; \
    echo "   Run: devenv up -d"; \
  fi

# Run database migrations
db-migrate:
  @just db-ensure
  @echo "🗄️  Running migrations..."
  mix ecto.migrate

# Rollback last migration
db-rollback:
  @just db-ensure
  @echo "⏪ Rolling back last migration..."
  mix ecto.rollback

# Reset database (drop, create, migrate, seed)
db-reset:
  @just db-ensure
  @echo "🗑️  Resetting database..."
  mix ecto.reset
  @echo "✅ Database reset complete"

# Create a new migration
db-new-migration NAME:
  @echo "📝 Creating migration: {{NAME}}..."
  mix ecto.gen.migration {{NAME}}

# Seed the database
db-seed:
  @just db-ensure
  @echo "🌱 Seeding database..."
  mix run priv/repo/seeds.exs

# ==============================================================================
# QUALITY & CI
# ==============================================================================

# Run all quality checks (matches CI pipeline)
quality: quality-format quality-compile quality-lint quality-security quality-deps quality-nix
  @echo "✅ All quality checks passed!"

# Check code formatting (don't modify) - parallelized
quality-format:
  @echo "📝 Checking formatting..."
  @mix format --check-formatted & \
  nix fmt -- --check . & \
  wait

# Compile with warnings as errors
quality-compile:
  @echo "🔨 Compiling with strict warnings..."
  mix compile --force --warnings-as-errors

# Run linters (Credo) - parallelized
quality-lint:
  @echo "🔍 Running linters..."
  @mix credo --strict --all

# Security checks (Sobelow + audits) - parallelized
quality-security:
  @echo "🔒 Running security checks..."
  @mix sobelow --config & \
  mix deps.audit & \
  wait

# Check dependencies (unused deps)
quality-deps:
  @echo "📦 Checking dependencies..."
  mix deps.unlock --check-unused

# Check Nix flake (evaluates and runs Nix checks)
quality-nix:
  @echo "❄️  Checking Nix flake..."
  nix flake check

# Full CI pipeline (run before pushing)
ci: quality test
  @echo "✅ CI pipeline passed! Safe to push."

# ==============================================================================
# TESTING & COVERAGE
# ==============================================================================

# Run all tests with coverage reports (slow)
coverage:
  @just db-ensure
  @echo "📊 Generating Elixir coverage..."
  MIX_ENV=test mix ecto.create --quiet || true
  MIX_ENV=test mix ecto.migrate --quiet
  MIX_ENV=test mix coveralls.html
  @echo "✅ Coverage reports generated:"
  @echo "   Elixir: cover/excoveralls.html"

# ==============================================================================
# DOCKER & DEPLOYMENT
# ==============================================================================

# Build Docker image
docker-build TAG="latest":
  @echo "🐳 Building Docker image..."
  docker build -t singularity-edge:{{TAG}} .
  @echo "✅ Image built: singularity-edge:{{TAG}}"

# Deploy to Fly.io
deploy:
  @echo "🚀 Deploying to Fly.io..."
  flyctl deploy

# Deploy to multiple regions
deploy-global:
  @echo "🌍 Deploying globally..."
  flyctl deploy
  @echo "📍 Scaling to multiple regions..."
  flyctl scale count 3 --region iad,lhr,nrt
  @echo "✅ Global deployment complete!"

# Rotate Fly.io secrets (run if compromised or periodically)
secrets-rotate:
  @echo "🔐 Rotating Fly.io secrets..."
  @echo "Generating new SECRET_KEY_BASE..."
  @SECRET_KEY_BASE=$(mix phx.gen.secret) && \
  echo "Generating new RELEASE_COOKIE..." && \
  RELEASE_COOKIE=$(openssl rand -base64 32) && \
  echo "Setting secrets on Fly.io..." && \
  flyctl secrets set -a singularity-edge \
    SECRET_KEY_BASE="$$SECRET_KEY_BASE" \
    RELEASE_COOKIE="$$RELEASE_COOKIE" && \
  echo "✅ Secrets rotated successfully!" && \
  echo "" && \
  echo "⚠️  IMPORTANT: Save these secrets in a secure location:" && \
  echo "   SECRET_KEY_BASE=$$SECRET_KEY_BASE" && \
  echo "   RELEASE_COOKIE=$$RELEASE_COOKIE"

# ==============================================================================
# DOCUMENTATION
# ==============================================================================

# Generate API documentation
docs:
  @echo "📚 Generating documentation..."
  mix deps.get --only docs
  mix docs
  @echo "✅ Documentation generated: doc/index.html"

# Open documentation in browser
docs-open: docs
  open doc/index.html

# ==============================================================================
# UTILITIES & ANALYSIS
# ==============================================================================

# Show code statistics
stats:
  @echo "📊 Code statistics:"
  @tokei

# Scan for hardcoded secrets
secrets:
  @echo "🔐 Scanning for secrets..."
  @gitleaks detect --no-git -v || true

# Check shell scripts
shellcheck:
  @echo "🐚 Checking shell scripts..."
  @find . -name "*.sh" -type f -not -path "*/node_modules/*" -not -path "*/_build/*" -not -path "*/deps/*" -not -path "*/.direnv/*" -exec shellcheck {} + || echo "No shell scripts found"

# Check for outdated dependencies
outdated:
  @echo "📦 Checking for outdated dependencies..."
  @echo "\n=== Elixir Dependencies ==="
  @mix hex.outdated

# ==============================================================================
# LEGACY ALIASES (for backwards compatibility)
# ==============================================================================

# Alias: setup (use 'init' instead)
setup: init

# Alias: server (use 'dev' instead)
server: dev

# Alias: format (use 'fmt' instead)
format: fmt

# Alias: migrate (use 'db-migrate' instead)
migrate: db-migrate
