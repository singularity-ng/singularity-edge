{
  description = "Singularity Edge - Global Load Balancer and Edge Routing Service";

  # Nix configuration for binary caches is handled by direnv in .envrc
  # This avoids approval prompts and provides better caching control
  # Priority order: Cachix > cache.nixos.org
  # Substituters configured in .envrc via NIX_CONFIG for automatic approval

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Following Nix Pills #12: Inputs Design Pattern
  # https://nixos.org/guides/nix-pills/12-inputs-design-pattern.html
  # - All inputs declared at top level (inputs = { ... })
  # - Outputs function takes inputs as arguments (no direct imports)
  # - Single nixpkgs import, passed down to packages
  # - Packages are independent and customizable via inputs
  outputs = { self, nixpkgs, flake-utils }:
    # Build for all default systems (Linux, macOS/Darwin, etc.)
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Single nixpkgs import (as per inputs pattern) - passed to all packages
        # Following Nix Pills #16: Nixpkgs Parameters
        # https://nixos.org/guides/nix-pills/16-nixpkgs-parameters.html
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;  # Required for unfree packages if needed
        };

        stdenv = pkgs.stdenv;

        # Import shared library functions
        lib = import ./nix/lib.nix { };

        # Import devShell modules
        devShells = {
          default = import ./nix/devShells/default.nix {
            inherit pkgs lib;
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
