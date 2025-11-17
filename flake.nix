{
  description = "Singularity Edge - Global Load Balancer and Edge Routing Service (Elixir/Phoenix)";

  # Nix configuration for binary caches is handled by direnv in .envrc
  # This avoids approval prompts and provides better caching control
  # Priority order: Cachix > cache.nixos.org
  # Substituters configured in .envrc via NIX_CONFIG for automatic approval

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";
  };

  # Following Nix Pills #12: Inputs Design Pattern
  # https://nixos.org/guides/nix-pills/12-inputs-design-pattern.html
  outputs = { self, nixpkgs, flake-utils, devenv }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
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
