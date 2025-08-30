{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;

  # Import the library
  nix-helm-generator = import ../lib {};

  # Test cases
  testBasicChart = nix-helm-generator.mkChart {
    name = "test-app";
    version = "1.0.0";
    description = "Basic test application";

    app = {
      image = "nginx:alpine";
      replicas = 2;
      ports = [80 443];
      env = {
        APP_ENV = "test";
        DEBUG = "true";
      };
    };
  };

  testProductionChart = nix-helm-generator.mkChart {
    name = "production-app";
    version = "1.0.0";
    description = "Production test application";

    app = {
      image = "nginx:alpine";
      replicas = 3;
      ports = [80];

      production = {
        pdb = {
          enabled = true;
          minAvailable = "50%";
        };

        resources = {
          requests = {
            cpu = "100m";
            memory = "128Mi";
          };
          limits = {
            cpu = "500m";
            memory = "512Mi";
          };
        };

        healthChecks = {
          readinessProbe = {
            httpGet = {
              path = "/health";
              port = 80;
            };
            initialDelaySeconds = 5;
            periodSeconds = 10;
          };
        };

        securityContext = {
          pod = {
            runAsNonRoot = true;
            runAsUser = 101;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = true;
          };
        };
      };
    };
  };

  # Test validation
  testValidation = {
    validChart = testBasicChart;
    productionChart = testProductionChart;
  };

in
{
  inherit testBasicChart testProductionChart testValidation;

  # Test results
  results = {
    basicChartGenerated = testBasicChart ? yamlOutput;
    productionChartGenerated = testProductionChart ? yamlOutput;
    basicYamlValid = lib.isString testBasicChart.yamlOutput;
    productionYamlValid = lib.isString testProductionChart.yamlOutput;
  };
}