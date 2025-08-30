let
  nix-helm-generator = import ./lib {};
in
# Test with invalid name (empty string)
nix-helm-generator.mkChart {
  name = "";
  version = "1.0.0";
  description = "Invalid chart - empty name";
}