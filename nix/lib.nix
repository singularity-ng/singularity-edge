# Shared utility functions for flake modules
# Used across devShells and other modules

{ ... }:

rec {
  # Common tool sets used across devShells
  commonTools = pkgs: with pkgs; [
    # === Core Elixir/Erlang Toolchain ===
    beam.packages.erlang_28.elixir_1_19
    beam.packages.erlang_28.erlang

    # === Core Build Dependencies ===
    pkg-config
    openssl
    cacert

    # === General Code Quality Tools ===
    tokei              # Fast code line counter
    gitleaks           # Secret scanning
    shellcheck         # Shell script linting
    yamllint           # YAML file linting
    nodejs_22          # Node runtime (for assets)
    bun                # Fast JavaScript runtime
  ];

  devTools = pkgs: with pkgs; [
    # === Development Tools ===
    git                # Version control
    gh                 # GitHub CLI
    flyctl             # Fly.io CLI
    just               # Task runner
    direnv             # Environment management
    jq                 # JSON processor
    curl               # HTTP client
    cachix             # Nix binary cache
    postgresql_17      # PostgreSQL database
  ];

  rustTools = { pkgs, rustToolchain }: with pkgs; [
    # === Core Rust Toolchain ===
    rustToolchain      # cargo, rustc, rustfmt, clippy, rust-analyzer
    rust-analyzer      # IDE support
    sccache            # Rust compilation cache

    # === Essential Cargo Tools ===
    cargo-edit         # cargo add/rm/upgrade commands
    cargo-watch        # Auto-run on file changes

    # === Quality & Security Tools ===
    cargo-audit        # Security vulnerability checking
    cargo-deny         # License and security policy
  ];

  # Common shellHook components
  setupEnvironment = pkgs: ''
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export SSL_CERT_DIR=${pkgs.cacert}/etc/ssl/certs
  '';

  setupElixir = ''
    # Elixir/Mix environment
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export ERL_AFLAGS="-kernel shell_history enabled"
  '';

  setupRust = ''
    # Rust environment
    export RUST_BACKTRACE=1
    export CARGO_HOME=$PWD/.nix-cargo
    export RUST_LOG=info

    # Configure sccache for Rust compilation caching
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
      export RUSTC_WRAPPER=sccache
      export SCCACHE_DIR=$PWD/.sccache
      mkdir -p $SCCACHE_DIR
    fi
  '';

  setupPaths = ''
    # Add local bins to PATH
    export PATH=$PWD/node_modules/.bin:$MIX_HOME/bin:$HEX_HOME/bin:$CARGO_HOME/bin:$HOME/.cargo/bin:$PATH
  '';

  installDeps = ''
    # Install hex and rebar if not present
    if [ ! -d "$MIX_HOME/archives" ] || [ -z "$(ls -A "$MIX_HOME/archives" 2>/dev/null)" ]; then
      echo "📦 Installing Hex and Rebar..."
      mix local.hex --force
      mix local.rebar --force
    fi

    # Install npm dependencies if needed
    if [ -f "$PWD/assets/package.json" ] && [ ! -d "$PWD/assets/node_modules" ]; then
      echo "📦 Installing npm dependencies..."
      (cd assets && npm install)
    fi
  '';

  setupGitHooks = ''
    # Setup git hooks if they exist
    if [ -f ./setup-hooks.sh ]; then
      ./setup-hooks.sh 2>/dev/null || true
    fi
  '';
}
