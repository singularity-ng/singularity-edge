# FlakeCache - Development Task Runner
# Run `just` to see all available commands

# Default recipe - show interactive command picker
default:
  @just --choose

# ==============================================================================
# SETUP & ENVIRONMENT
# ==============================================================================

# Initial project setup (run once)
init:
  @echo "🚀 Initializing FlakeCache development environment..."
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
  cargo clean --manifest-path=native/nar_handler/Cargo.toml
  rm -rf _build deps .nix-mix .nix-hex .nix-cargo cover
  @echo "✅ Clean complete!"

# Update all dependencies
update:
  @echo "📦 Updating Elixir dependencies..."
  mix deps.update --all
  @echo "📦 Updating Rust dependencies..."
  cargo update --manifest-path=native/nar_handler/Cargo.toml
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

# Format all code (Elixir + Rust)
fmt:
  @echo "📝 Formatting code..."
  mix format
  cargo fmt --manifest-path=native/nar_handler/Cargo.toml
  @echo "✅ Code formatted!"

# Quick pre-commit checks (fast feedback ~30s)
check: fmt
  @echo "🔍 Running quick checks..."
  mix compile --warnings-as-errors
  mix credo --strict
  cargo clippy --manifest-path=native/nar_handler/Cargo.toml -- -D warnings
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
quality: quality-format quality-compile quality-lint quality-docs quality-types quality-security quality-deps
  @echo "✅ All quality checks passed!"

# Check code formatting (don't modify)
quality-format:
  @echo "📝 Checking formatting..."
  @mix format --check-formatted & \
  cargo fmt --manifest-path=native/nar_handler/Cargo.toml -- --check & \
  wait

# Compile with warnings as errors
quality-compile:
  @echo "🔨 Compiling with strict warnings..."
  mix compile --force --warnings-as-errors

# Run linters (Credo + Clippy) - parallelized
quality-lint:
  @echo "🔍 Running linters..."
  @mix credo --strict --all & \
  cargo clippy --manifest-path=native/nar_handler/Cargo.toml --all-targets --all-features -- \
    -W clippy::pedantic \
    -W clippy::nursery \
    -W clippy::cargo \
    -A clippy::multiple-crate-versions \
    -A clippy::module-name-repetitions \
    -D warnings & \
  wait

# Documentation coverage (must run before Dialyzer to ensure 100% spec coverage)
quality-docs:
  @echo "📚 Checking documentation coverage..."
  mix doctor --summary

# Type checking (Dialyzer)
quality-types:
  @echo "🔬 Running type checks..."
  mix dialyzer

# Security checks (Sobelow + audits) - parallelized
quality-security:
  @echo "🔒 Running security checks..."
  @mix sobelow --config & \
  mix deps.audit & \
  (cd native/nar_handler && cargo audit) & \
  (cd native/nar_handler && cargo deny check) & \
  wait

# Check dependencies (unused deps)
quality-deps:
  @echo "📦 Checking dependencies..."
  mix deps.unlock --check-unused

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
  @echo "📊 Generating Rust coverage..."
  cargo tarpaulin --manifest-path=native/nar_handler/Cargo.toml --out Html --output-dir cover/rust
  @echo "✅ Coverage reports generated:"
  @echo "   Elixir: cover/excoveralls.html"
  @echo "   Rust:   cover/rust/index.html"

# Run Rust tests
test-rust:
  @echo "🧪 Running Rust tests..."
  cargo test --manifest-path=native/nar_handler/Cargo.toml

# ==============================================================================
# DOCKER & DEPLOYMENT
# ==============================================================================

# Build Docker image using Nix
docker-build TAG="latest":
  @echo "🐳 Building Docker image with Nix..."
  nix build .#docker
  docker load < result
  docker tag flakecache:latest flakecache:{{TAG}}
  @echo "✅ Image built: flakecache:{{TAG}}"

# Build and push Docker image to Fly.io
docker-push TAG:
  @echo "🚀 Building and pushing to Fly.io registry..."
  ./deploy/build-and-push-docker.sh registry.fly.io/flakecache-prod {{TAG}}

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
  @find . -name "*.sh" -type f -not -path "*/node_modules/*" -not -path "*/_build/*" -not -path "*/deps/*" -exec shellcheck {} +

# Check for outdated dependencies
outdated:
  @echo "📦 Checking for outdated dependencies..."
  @echo "\n=== Elixir Dependencies ==="
  @mix hex.outdated
  @echo "\n=== Rust Dependencies ==="
  @cargo outdated --manifest-path=native/nar_handler/Cargo.toml

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
