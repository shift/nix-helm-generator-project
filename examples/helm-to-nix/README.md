# Helm-to-Nix Example

This example shows a Nix-first workflow to migrate a Helm chart into a Nix expression consumable by the nix-helm module.

Prerequisites (via flake devShell)
- helm
- python3 (PyYAML)

Steps

1. Render chart values and templates using helm inside the devShell:

   nix develop -c -- helm show values ./chart > chart.values.yaml
   nix develop -c -- helm template ./chart > rendered.yaml

2. Convert values YAML to JSON so Nix can read it:

   nix develop -c -- python3 -c "import sys,json,yaml; print(json.dumps(yaml.safe_load(sys.stdin)))" < chart.values.yaml > chart.values.json

3. Create a Nix expression that imports the JSON and applies simple transformations.

See `convert.nix` for the example Nix expression.

Notes
- This example uses a manual conversion step (YAML -> JSON) run in the devShell; the final migration logic is pure Nix.
- For complex charts, manual inspection and edits will still be needed.
