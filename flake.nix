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
      let
        myPackages = {
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

        myDevShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            kubernetes-helm
            kubectl
            yq
            jq
            python3Packages.pyyaml
          ];

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

        myLib = import ./lib { inherit pkgs; };

        myApps = {
          my-app = {
            type = "app";
            program = "${pkgs.writeShellScript "output-my-app" ''\
              exec echo '${builtins.toJSON (self.my-app.${system})}'\
            ''}";
          };
          multi-app = {
            type = "app";
            program = "${pkgs.writeShellScript "output-multi-app" ''\
              exec echo '${builtins.toJSON (self.multi-app.${system})}'\
            ''}";
          };
        };

        # Test applications
        myAppValue = (import ./lib { inherit pkgs; }).mkChart {
          name = "my-app";
          version = "1.0.0";
          description = "Test application";
          appVersion = "1.0.0";
          app = {
            image = "nginx:1.25.0";
            ports = [80];
          };
        };

        multiAppValue = (import ./lib { inherit pkgs; }).mkMultiChart {
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
      in
      {
        packages = myPackages;
        devShells = {
          default = myDevShell;
        };
        lib = myLib;
        apps = myApps;
        my-app = myAppValue;
        multi-app = multiAppValue;

        checks = {
          examples-test = pkgs.runCommand "examples-test" {
            buildInputs = [ pkgs.kubernetes-helm pkgs.yq pkgs.python3 pkgs.jq pkgs.kubectl pkgs.bash ];
          } ''
            set -euo pipefail
            mkdir -p $out
            cp -r ${./examples/helm-to-nix/worked-example} $out/worked-example
            cd $out/worked-example
            chmod +x ./checks.sh
            ${pkgs.bash}/bin/bash ./checks.sh
            echo "Examples test passed" > $out/result
          '';
        };
        # expose checks under legacyPackages as well
        legacyPackages = if pkgs ? checks then { inherit (pkgs) checks; } else { };
      }
    );
}
