{
  description = "Nix Helm Generator - Generate production-ready Helm charts from Nix expressions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = self.packages.${system}.nix-helm-generator;
          nix-helm-generator = import ./lib { inherit pkgs; };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            kubernetes-helm
            kubectl
            yq
            jq
            python3Packages.pyyaml
          ];

          shellHook = ''
            echo "Nix Helm Generator Development Environment"
            echo "Available commands:"
            echo "  nix build .#nix-helm-generator"
            echo "  nix develop"
          '';
        };

        # Expose the library for use in other flakes
        lib = import ./lib { inherit pkgs; };
      }
    );
}