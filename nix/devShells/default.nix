# Default development shell with Elixir, Rust, and all tools
# Full-featured development environment for singularity-edge

{ pkgs, rustToolchain, lib }:

pkgs.mkShell {
  name = "singularity-edge-devshell";

  nativeBuildInputs =
    (lib.commonTools pkgs)
    ++ (lib.devTools pkgs)
    ++ (lib.rustTools { inherit pkgs rustToolchain; });

  shellHook = ''
    ${lib.setupEnvironment pkgs}
    ${lib.setupElixir}
    ${lib.setupRust}

    # Load and configure Fly.io API token (shared function)
    ${lib.loadFlyToken}

    ${lib.setupPaths}
    ${lib.installDeps}

    echo "🚀 Singularity Edge Development Environment"
    echo ""
    echo "📦 Quick start:"
    echo "  just             - Interactive command picker"
    echo "  just init        - Initialize project (first time)"
    echo "  just dev         - Start development server"
    echo "  just test        - Run tests"
    echo "  just check       - Quick pre-commit checks"
    echo ""
    echo "📚 Run 'just --list' for all available commands"

    ${lib.setupGitHooks}
  '';
}
