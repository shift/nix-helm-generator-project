#! /bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# Ensure we're in devShell when running heavy tools
# During hermetic builds, IN_NIX_SHELL won't be set; allow running when build tools are present
# If running interactively, recommend devShell but do not fail
if [ -z "${IN_NIX_SHELL:-}" ]; then
  echo "Warning: not in nix devShell - proceeding in hermetic build environment" >&2
fi

# Render with helm and convert
helm show values "$here" > "$here/out-values.yaml"
helm template "$here" > "$here/out-rendered.yaml"
# convert YAML->JSON: prefer yq v4, then yq v3, then python fallback
if command -v yq >/dev/null 2>&1; then
  if yq --version 2>/dev/null | grep -q "version"; then
    # yq v4+ (mikefarah)
    if yq eval -o=json '.' "$here/out-values.yaml" > "$here/out-values.json" 2>/dev/null; then
      echo "converted with yq eval"
    elif yq -o=json '.' "$here/out-values.yaml" > "$here/out-values.json" 2>/dev/null; then
      echo "converted with yq -o=json"
    else
      echo "yq present but conversion failed, falling back to python"
      python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$here/out-values.yaml" > "$here/out-values.json"
    fi
  else
    # unknown yq, try common invocations
    if yq eval -o=json '.' "$here/out-values.yaml" > "$here/out-values.json" 2>/dev/null; then
      echo "converted with yq eval"
    elif yq -o=json '.' "$here/out-values.yaml" > "$here/out-values.json" 2>/dev/null; then
      echo "converted with yq -o=json"
    else
      echo "yq present but conversion failed, falling back to python"
      python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$here/out-values.yaml" > "$here/out-values.json"
    fi
  fi
else
  # fallback to python
  python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$here/out-values.yaml" > "$here/out-values.json"
fi


# Load into nix expression
(cd "$here" && nix-instantiate --eval -E "let pkgs = import <nixpkgs> {}; demo = import ./example.nix { inherit pkgs; }; in demo.replicas") | sed -n '1p'

# Simple content checks
grep -q "kind: Deployment" "$here/out-rendered.yaml"
grep -q "containerPort: 80" "$here/out-rendered.yaml"

echo "checks passed"
