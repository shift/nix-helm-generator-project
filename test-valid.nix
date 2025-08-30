let
  nix-helm-generator = import ./lib {};
in
# Test with valid configuration
nix-helm-generator.mkChart {
  name = "valid-app";
  version = "1.0.0";
  description = "Valid test chart";
}