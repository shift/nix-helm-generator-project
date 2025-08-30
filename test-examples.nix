let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  # Import the Nix Helm Generator
  nixHelm = import ./lib {};

  # Test all examples
  examples = {
    nginx = import ./examples/nginx.nix { inherit lib; };
    redis = import ./examples/redis.nix { inherit lib; };
    postgres = import ./examples/postgres.nix { inherit lib; };
    prometheus = import ./examples/prometheus.nix { inherit lib; };
    elasticsearch = import ./examples/elasticsearch.nix { inherit lib; };
    cert-manager = import ./examples/cert-manager.nix { inherit lib; };
    ingress-nginx = import ./examples/ingress-nginx.nix { inherit lib; };
  };

  # Test results
  testResults = builtins.mapAttrs (name: example:
    {
      name = name;
      yamlGenerated = lib.isString example.yamlOutput;
      yamlLength = builtins.stringLength example.yamlOutput;
      hasChartMetadata = example ? chartMeta;
      hasK8sResources = example ? k8sResources;
      hasProductionResources = example ? productionResources;
    }
  ) examples;

in
{
  inherit examples testResults;

  # Summary
  summary = {
    totalExamples = builtins.length (builtins.attrNames examples);
    allYamlGenerated = builtins.all (result: result.yamlGenerated) (builtins.attrValues testResults);
    totalYamlSize = builtins.foldl' (acc: result: acc + result.yamlLength) 0 (builtins.attrValues testResults);
  };
}