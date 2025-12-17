# Migrating Helm charts to Nix (research + how-to)

This document describes a Nix-only workflow to convert an existing Helm chart (including its rendered template output and values.yaml) into the Nix expressions expected by the nix-helm module in this repository.

Goals
- Use only Nix tooling (no external scripting languages).
- Use Helm to render templates and emit values.yaml (helm template + helm show values).
- Consume the YAML in Nix, transform it into the structure used by the module (Nix attrsets/lists).
- Produce a Nix expression that can be dropped into `examples/` or integrated into the module.

Constraints and assumptions
- Nix can read YAML using built-in libyaml support or via small utilities available in the devShell (we prefer pure Nix where possible).
- The helm CLI is used only to render templates (not for runtime operations). The generated YAML is fed into Nix.
- The target Nix structure is the module's `values` attrset (see `lib/chart.nix` for expected keys). This document assumes a single top-level attrset mapping chart values to their usage.

Overview of the process
1. Use Helm to output the chart's default values and the rendered manifests:
   - `helm show values ./chart > chart.values.yaml`
   - `helm template ./chart --output-dir out` or `helm template ./chart > rendered.yaml`
2. Import the `chart.values.yaml` into Nix and convert it to a Nix attrset.
3. Inspect the rendered manifests to find which values are actually used and how they map to Kubernetes manifests; optionally prune unused values.
4. Using a Nix function, transform the values attrset into the shape used by the nix-helm module.
5. Emit a Nix file (example: `examples/<chart>.nix`) that defines the `chart` attrset and uses the module.

Nix primitives we will use
- builtins.fromJSON / builtins.readFile — limited for YAML; but we can use the `yaml` library available in Nixpkgs (`libyaml`) or `yaml` from pythonPackages if available in devShell. Prefer: `builtins.fromJSON` after converting YAML -> JSON via `yq` (but that uses an external tool).
- Prefer pure Nix: import `builtins.readFile` and use a small Nix expression to parse YAML using `yaml` from `nixpkgs.lib` (see examples below).

Recommended devShell tooling
- `helm` CLI (for rendering templates and getting values)
- `yq` (optional) to convert YAML -> JSON for easy `builtins.fromJSON` ingestion

Pure-Nix alternative (no external `yq`)
- Nixpkgs provides `lib.strings.split`, `lib.optionalAttrs`, `lib.attrsets` helpers — but parsing complex YAML in pure Nix is brittle.
- Better approach: add `python3` and `python3Packages.ruamel_yaml` or `python3Packages.pyyaml` into the devShell and use a small one-liner to convert YAML to JSON that Nix can read via `builtins.fromJSON`.

Proposed Nix-only pattern (uses python in devShell but final conversion stays in Nix):

1. Instruct the user to run in the project's devShell (flake devShell) where `helm` and `python3` are available:

   nix develop -c -- helm show values ./chart > chart.values.yaml
   nix develop -c -- helm template ./chart > rendered.yaml

2. Convert values YAML -> JSON so Nix can parse it without external Nix yaml parser:

   nix develop -c -- python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin)))" < chart.values.yaml > chart.values.json

3. In Nix expression, read the JSON and construct the chart expression:

   let
     valuesJson = builtins.fromJSON (builtins.readFile ./chart.values.json);
     chartAttrs = {
       name = "my-chart";
       version = "x.y.z"; # fill manually or extract
       values = valuesJson; # may need transformation
     };
   in
   chartAttrs

4. If transformations are needed (for example, flattening nested keys or renaming keys to match module schema), write small Nix helper functions to map/rename keys.

Example: basic transformation helper

  let
    mapKeys = attrs: builtins.foldl' (acc: key:
      let v = attrs."${key}"; newKey = if key == "oldName" then "newName" else key;
      in builtins.recursiveUpdate acc { ${newKey} = v; }
    ) {} (builtins.attrNames attrs);
  in mapKeys valuesJson

Caveats and limitations
- Exact 1:1 mapping from Helm values to the nix module's expected structure may be impossible automatically for complex charts; manual review will still be necessary.
- Some charts compute values or use templates that change structure depending on conditional logic; rendered manifests can be inspected to infer necessary keys but not guarantee completeness.
- Multi-document YAML: `helm template` outputs many manifests; these can be used to locate what values were consumed but mapping back to the values key path is manual unless templates include comments.

Suggested implementation plan for module support
1. Add a `examples/helm-to-nix` example that demonstrates converting a chart using the workflow above.
2. Add a Nix helper library in `lib/helm-migration.nix` which:
   - Accepts a path to a JSON-converted values file (or accepts an attrset directly)
   - Provides helper functions for common renames/flattening used by this repo's module
   - Offers a function to produce a `chart` attrset ready for inclusion in examples.
3. Update README and `docs/MIGRATE_HELM_TO_NIX.md` with step-by-step commands.

Minimal example file (examples/helm-to-nix/convert.nix)

  let
    pkgs = import <nixpkgs> {};
    values = builtins.fromJSON (builtins.readFile ./chart.values.json);
    migrated = lib.helmMigration.defaultTransform values;
  in
  {
    chart = {
      name = "my-chart";
      source = ./chart; # or specify repo
      values = migrated;
    };
  }

Next steps
- Create `examples/helm-to-nix/README.md` with concrete commands and a tiny sample.
- Optionally implement `lib/helm-migration.nix` with a few transformation helpers.

Files added
- docs/MIGRATE_HELM_TO_NIX.md (this file)

Completion
This is a working research + how-to draft that outlines a Nix-first approach while accepting a small conversion step (yaml->json) executed in the devShell. If you want, I can now:
- Add the `examples/helm-to-nix/README.md` with concrete commands and a tiny sample chart
- Implement `lib/helm-migration.nix` with helper functions and a simple example `examples/helm-to-nix/convert.nix`

Choose next action: add examples only, or add examples + helpers.