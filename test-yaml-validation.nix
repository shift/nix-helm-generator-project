let
  tests = import ./tests/default.nix {};
  lib = import <nixpkgs> {}.lib;
in
let
  # Test basic chart YAML
  basicYaml = tests.testBasicChart.yamlOutput;
  basicYamlLines = lib.splitString "\n" basicYaml;

  # Test production chart YAML
  productionYaml = tests.testProductionChart.yamlOutput;
  productionYamlLines = lib.splitString "\n" productionYaml;

  # Validation functions
  hasChartMetadata = lib.any (line: lib.hasPrefix "# Chart.yaml" line) basicYamlLines;
  hasValuesFile = lib.any (line: lib.hasPrefix "# values.yaml" line) basicYamlLines;
  hasDeployment = lib.any (line: lib.hasPrefix "apiVersion: apps/v1" line && lib.any (line2: lib.hasPrefix "kind: Deployment" line2) basicYamlLines) basicYamlLines;
  hasService = lib.any (line: lib.hasPrefix "apiVersion: v1" line && lib.any (line2: lib.hasPrefix "kind: Service" line2) basicYamlLines) basicYamlLines;

  # Production features validation
  hasPDB = lib.any (line: lib.hasPrefix "apiVersion: policy/v1" line && lib.any (line2: lib.hasPrefix "kind: PodDisruptionBudget" line2) productionYamlLines) productionYamlLines;
  hasResources = lib.any (line: lib.hasPrefix "resources:" line) productionYamlLines;
  hasReadinessProbe = lib.any (line: lib.hasPrefix "readinessProbe:" line) productionYamlLines;
  hasSecurityContext = lib.any (line: lib.hasPrefix "securityContext:" line) productionYamlLines;

in
{
  basicChart = {
    hasChartMetadata = hasChartMetadata;
    hasValuesFile = hasValuesFile;
    hasDeployment = hasDeployment;
    hasService = hasService;
    yamlLength = lib.length basicYamlLines;
  };

  productionChart = {
    hasPDB = hasPDB;
    hasResources = hasResources;
    hasReadinessProbe = hasReadinessProbe;
    hasSecurityContext = hasSecurityContext;
    yamlLength = lib.length productionYamlLines;
  };

  overall = let
    basicValid = hasChartMetadata && hasValuesFile && hasDeployment && hasService;
    productionValid = hasPDB && hasResources && hasReadinessProbe && hasSecurityContext;
  in {
    inherit basicValid productionValid;
    allTestsPass = basicValid && productionValid;
  };
}