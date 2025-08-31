 { pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;

   # Import all library modules
   chart = import ./chart.nix { inherit lib; };
   resources = import ./resources.nix { inherit lib; };
   production = import ./production.nix { inherit lib; };
   validation = import ./validation.nix { inherit lib; };
   multiChart = import ./multi-chart.nix { inherit lib chart resources production validation mkChart; };
   dependency = import ./dependency.nix { inherit lib; };
   shared = import ./shared.nix { inherit lib; };

   # Core mkChart function (single chart)
   mkChart = config:
     let
       # Validate input configuration
       validatedConfig = validation.validateChartConfig config;

       # Additional app validation if present
       appValidated = if config ? app
         then let result = validation.validateAppConfig config.app;
              in if !result.valid
                 then throw "App validation failed:\n${lib.concatStringsSep "\n" result.errors}"
                 else config
         else config;

      # Generate chart metadata
      chartMeta = chart.mkChartMetadata validatedConfig;

      # Generate Kubernetes resources
      k8sResources = resources.mkResources validatedConfig;

      # Apply production features
      productionResources = production.mkProductionResources validatedConfig k8sResources;

      # Generate YAML output
      yamlOutput = chart.mkYamlOutput chartMeta productionResources;
    in
    {
      inherit chartMeta k8sResources productionResources yamlOutput;

      # Convenience functions
      toString = yamlOutput;
      toFile = name: pkgs.writeText name yamlOutput;
    };

   # Multi-chart function
   mkMultiChart = config:
     let
       # Check if this is a multi-chart configuration
       isMultiChart = config ? charts && lib.isAttrs config.charts;

       result = if isMultiChart
         then multiChart.mkMultiChart config
         else throw "Not a valid multi-chart configuration. Use mkChart for single charts.";
     in result;

in
{
  inherit mkChart mkMultiChart;

  # Expose individual modules for advanced usage
  inherit chart resources production validation multiChart dependency shared;

  # Utility functions
  utils = {
    toYaml = lib.generators.toYAML {};
    fromYaml = builtins.fromJSON; # Note: requires JSON-compatible YAML
  };
}