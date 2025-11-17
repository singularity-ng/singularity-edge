{
  description = "Singularity Edge - Global Load Balancer and Edge Routing Service (Elixir/Phoenix + Rust CLI)";

  # Nix configuration for binary caches is handled by direnv in .envrc
  # This avoids approval prompts and provides better caching control
  # Priority order: Cachix > cache.nixos.org
  # Substituters configured in .envrc via NIX_CONFIG for automatic approval

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  # Following Nix Pills #12: Inputs Design Pattern
  # https://nixos.org/guides/nix-pills/12-inputs-design-pattern.html
  outputs = { self, nixpkgs, rust-overlay, flake-utils, crane, advisory-db }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

        stdenv = pkgs.stdenv;

        # Rust toolchain with all extensions (for development)
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

        # Crane library for building Rust CLI
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Import shared library functions
        lib = import ./nix/lib.nix { };

        # Import devShell modules
        devShells = {
          default = import ./nix/devShells/default.nix {
            inherit pkgs rustToolchain lib;
          };
        };

      in
      {
        inherit devShells;

        # Formatter for nix files
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
