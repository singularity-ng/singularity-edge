# Default development shell with core tools
# Minimal setup for singularity-edge development

{ pkgs, lib }:

pkgs.mkShell {
  name = "singularity-edge-devshell";

  nativeBuildInputs =
    (lib.commonTools pkgs)
    ++ (lib.devTools pkgs);

  shellHook = ''
    ${lib.setupEnvironment pkgs}
    ${lib.setupPaths}

    echo "🚀 Singularity Edge Development Environment"
    echo ""
    echo "📦 Quick start:"
    echo "  just             - Interactive command picker"
    echo "  just --list      - List all available commands"
    echo ""

    ${lib.setupGitHooks}
  '';
}
