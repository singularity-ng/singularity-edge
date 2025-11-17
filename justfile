# Singularity Edge - Task Runner
# Run 'just' for interactive picker or 'just --list' to see all commands

# Default recipe: interactive picker
default:
    @just --choose

# Show available commands
list:
    @just --list

# Format all code
fmt:
    @echo "📝 Formatting Nix files..."
    nix fmt

# Check Nix flake
check:
    @echo "✅ Checking Nix flake..."
    nix flake check

# Update flake inputs
update:
    @echo "📦 Updating flake inputs..."
    nix flake update

# Show code statistics
stats:
    @echo "📊 Code statistics:"
    @tokei

# Clean build artifacts
clean:
    @echo "🗑️  Cleaning build artifacts..."
    rm -rf result result-*
    @echo "✅ Clean complete"
