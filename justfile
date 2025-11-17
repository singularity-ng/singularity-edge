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
  @echo "✅ Setup complete! Development environment ready."

# Clean all build artifacts and caches
clean:
  @echo "🧹 Cleaning build artifacts..."
  rm -rf result result-* .direnv/store
  @echo "✅ Clean complete!"

# Update all dependencies
update:
  @echo "📦 Updating Nix flake inputs..."
  nix flake update
  @echo "✅ Dependencies updated!"

# ==============================================================================
# DEVELOPMENT WORKFLOW
# ==============================================================================

# Format all code (Nix)
fmt:
  @echo "📝 Formatting Nix files..."
  nix fmt
  @echo "✅ Code formatted!"

# Quick pre-commit checks (fast feedback)
check: fmt
  @echo "🔍 Running quick checks..."
  nix flake check
  @echo "✅ Quick checks passed!"

# ==============================================================================
# QUALITY & CI
# ==============================================================================

# Run all quality checks
quality: quality-format quality-nix
  @echo "✅ All quality checks passed!"

# Check code formatting (don't modify)
quality-format:
  @echo "📝 Checking Nix formatting..."
  nix fmt -- --check .

# Check Nix flake
quality-nix:
  @echo "🔍 Checking Nix flake..."
  nix flake check

# Full CI pipeline (run before pushing)
ci: quality
  @echo "✅ CI pipeline passed! Safe to push."

# ==============================================================================
# DOCKER & DEPLOYMENT
# ==============================================================================

# Build Docker image using Nix (when implemented)
docker-build TAG="latest":
  @echo "🐳 Building Docker image with Nix..."
  @echo "⚠️  Docker build not yet implemented"
  @echo "   Add docker package to flake.nix first"

# ==============================================================================
# DOCUMENTATION
# ==============================================================================

# Generate API documentation (when implemented)
docs:
  @echo "📚 Generating documentation..."
  @echo "⚠️  Documentation generation not yet implemented"

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

# ==============================================================================
# LEGACY ALIASES (for backwards compatibility)
# ==============================================================================

# Alias: setup (use 'init' instead)
setup: init

# Alias: format (use 'fmt' instead)
format: fmt
