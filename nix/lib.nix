# Shared utility functions for flake modules
# Used across devShells and other modules

{ ... }:

rec {
  # Common tool sets used across devShells
  commonTools = pkgs: with pkgs; [
    # === Core Build Dependencies ===
    pkg-config
    openssl
    cacert

    # === General Code Quality Tools ===
    tokei              # Fast code line counter
    gitleaks           # Secret scanning
    shellcheck         # Shell script linting
    yamllint           # YAML file linting
  ];

  devTools = pkgs: with pkgs; [
    # === Development Tools ===
    git                # Version control
    gh                 # GitHub CLI
    just               # Task runner
    direnv             # Environment management
    jq                 # JSON processor
    curl               # HTTP client
    cachix             # Nix binary cache
  ];

  # Common shellHook components
  setupEnvironment = pkgs: ''
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export SSL_CERT_DIR=${pkgs.cacert}/etc/ssl/certs
  '';

  setupPaths = ''
    # Add local bins to PATH
    export PATH=$PWD/bin:$HOME/.local/bin:$PATH
  '';

  setupGitHooks = ''
    # Setup git hooks if they exist
    if [ -f ./setup-hooks.sh ]; then
      ./setup-hooks.sh 2>/dev/null || true
    fi
  '';
}
