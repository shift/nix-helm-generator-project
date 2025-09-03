#! /bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# when run in hermetic tmpdir, prefer writable WORKDIR env if set
workdir=${WORKDIR:-$here}

# Ensure we're in devShell when running heavy tools
# During hermetic builds, IN_NIX_SHELL won't be set; allow running when build tools are present
# If running interactively, recommend devShell but do not fail
if [ -z "${IN_NIX_SHELL:-}" ]; then
  echo "Warning: not in nix devShell - proceeding in hermetic build environment" >&2
fi

# Render with helm and convert
helm show values "$here" > "$workdir/out-values.yaml" 2>/dev/null || helm show values "$here" > "$workdir/out-values.yaml"
helm template "$here" > "$workdir/out-rendered.yaml" 2>/dev/null || helm template "$here" > "$workdir/out-rendered.yaml"
# convert YAML->JSON: prefer yq v4, then yq v3, then python fallback
if command -v yq >/dev/null 2>&1; then
  if yq --version 2>/dev/null | grep -q "version"; then
    # yq v4+ (mikefarah)
    if yq eval -o=json '.' "$workdir/out-values.yaml" > "$workdir/out-values.json" 2>/dev/null; then
      echo "converted with yq eval"
    elif yq -o=json '.' "$workdir/out-values.yaml" > "$workdir/out-values.json" 2>/dev/null; then
      echo "converted with yq -o=json"
    else
      echo "yq present but conversion failed, falling back to python"
      python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$workdir/out-values.yaml" > "$workdir/out-values.json"
    fi
  else
    # unknown yq, try common invocations
    if yq eval -o=json '.' "$workdir/out-values.yaml" > "$workdir/out-values.json" 2>/dev/null; then
      echo "converted with yq eval"
    elif yq -o=json '.' "$workdir/out-values.yaml" > "$workdir/out-values.json" 2>/dev/null; then
      echo "converted with yq -o=json"
    else
      echo "yq present but conversion failed, falling back to python"
      python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$workdir/out-values.yaml" > "$workdir/out-values.json"
    fi
  fi
else
  # fallback to python
  python -c 'import sys,yaml,json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$workdir/out-values.yaml" > "$workdir/out-values.json"
fi


# Load into nix expression
(cd "$here" && nix-instantiate --eval -E "let pkgs = import <nixpkgs> {}; demo = import ./example.nix { inherit pkgs; }; in demo.replicas") | sed -n '1p'

# Simple content checks
grep -q "kind: Deployment" "$workdir/out-rendered.yaml"
grep -q "containerPort: 80" "$workdir/out-rendered.yaml"

echo "checks passed"
