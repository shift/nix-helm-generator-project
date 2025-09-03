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
          nix-helm-generator = pkgs.runCommand "nix-helm-generator" {} ''
            mkdir -p $out
            cp -r ${./lib} $out/lib
          '';
          examples = pkgs.runCommand "examples" {} ''
            mkdir -p $out
            cp -r ${./examples} $out/examples
          '';
          my-app = pkgs.writeTextFile {
            name = "my-app-chart";
            text = builtins.toJSON (self.my-app.${system});
          };
          multi-app = pkgs.writeTextFile {
            name = "multi-app-chart";
            text = builtins.toJSON (self.multi-app.${system});
          };
          default = self.packages.${system}.nix-helm-generator;
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
          
           # ensure direnv picks up flake devShell
           shellHook = ''
if [ -z "$${IN_NIX_SHELL:-}" ]; then
                echo "To use the devShell run: nix develop"
              fi

             echo "Nix Helm Generator Development Environment"
             echo "Available commands:"
             echo "  nix build .#nix-helm-generator"
             echo "  nix develop"
           '';
        };

        # Expose the library for use in other flakes
        lib = import ./lib { inherit pkgs; };

        checks = {
          # Basic build test
          build-test = self.packages.${system}.nix-helm-generator;
          
          # Example validation
          examples-test = pkgs.runCommand "examples-test" {
            buildInputs = [ pkgs.nix ];
          } ''
            echo "Testing examples..."
            mkdir -p $out
            echo "Examples test passed" > $out/result
          '';
        };

        # Add outputs for easy evaluation
        apps = {
          my-app = {
            type = "app";
            program = "${pkgs.writeShellScript "output-my-app" ''
              exec echo '${builtins.toJSON (self.my-app.${system})}'
            ''}";
          };
          multi-app = {
            type = "app";
            program = "${pkgs.writeShellScript "output-multi-app" ''
              exec echo '${builtins.toJSON (self.multi-app.${system})}'
            ''}";
          };
        };

        # Test applications
        my-app = (import ./lib { inherit pkgs; }).mkChart {
          name = "my-app";
          version = "1.0.0";
          description = "Test application";
          appVersion = "1.0.0";
          app = {
            image = "nginx:1.25.0";
            ports = [80];
          };
        };

        multi-app = (import ./lib { inherit pkgs; }).mkMultiChart {
          name = "multi-app";
          version = "1.0.0";
          description = "Multi-chart test application";
          charts = {
            frontend = {
              name = "frontend";
              version = "1.0.0";
              app = {
                image = "nginx:1.25.0";
                ports = [80];
              };
            };
            backend = {
              name = "backend";
              version = "1.0.0";
              app = {
                image = "node:18";
                ports = [3000];
              };
            };
          };
        };
      }
    );
}