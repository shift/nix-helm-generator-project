let
  nix-helm-generator = import ./lib {};
in
# This should fail validation due to missing required fields
nix-helm-generator.mkChart {
  description = "Invalid chart - missing name and version";
}