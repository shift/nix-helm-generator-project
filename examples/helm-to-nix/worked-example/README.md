Worked example: demo Helm chart -> Nix

Steps to run locally:

1. Enter the flake devShell:

   nix develop

2. From this repository root run:

   cd examples/helm-to-nix/worked-example
   ./checks.sh

The script will render the chart with Helm, convert values.yaml -> values.json, evaluate the example Nix expression and run basic content checks.
