#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# Ensure we're in devShell when running heavy tools
if [ -z "${IN_NIX_SHELL:-}" ]; then
  echo "Not in nix devShell - run: nix develop" >&2
  exit 2
fi

# Render with helm and convert
helm show values "$here" > "$here/out-values.yaml"
helm template "$here" > "$here/out-rendered.yaml"
yq -o=json '.' "$here/out-values.yaml" > "$here/out-values.json"

# Load into nix expression
nix-instantiate --eval -E "let pkgs = import <nixpkgs> {}; demo = import '$here/example.nix' { inherit pkgs; }; in demo.replicas" | sed -n '1p'

# Simple content checks
grep -q "kind: Deployment" "$here/out-rendered.yaml"
grep -q "containerPort: 80" "$here/out-rendered.yaml"

echo "checks passed"
