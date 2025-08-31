# Test Multi-Chart Functionality

let
  nix-helm = import ./lib { };

  # Test configuration
  testConfig = {
    name = "test-multi-chart";
    version = "1.0.0";
    description = "Test multi-chart application";

    charts = {
      service1 = {
        name = "service1";
        version = "1.0.0";
        app = {
          name = "service1";
          image = "nginx";
          ports = [80];
        };
        resources = {
          deployment = { replicas = 1; };
          service = {
            type = "ClusterIP";
            ports = [{ port = 80; targetPort = 80; }];
          };
        };
      };

      service2 = {
        name = "service2";
        version = "1.0.0";
        app = {
          name = "service2";
          image = "nginx";
          ports = [8080];
        };
        resources = {
          deployment = { replicas = 2; };
          service = {
            type = "ClusterIP";
            ports = [{ port = 8080; targetPort = 8080; }];
          };
        };
      };
    };

    dependencies = [
      { name = "service1"; condition = "service1.enabled"; }
      { name = "service2"; condition = "service2.enabled"; }
    ];

    global = {
      namespace = "test";
      labels = {
        "app.kubernetes.io/managed-by" = "nix-helm-generator";
      };
    };
  };

in
# Generate the multi-chart
let
  result = nix-helm.mkMultiChart testConfig;
in
{
  # Test outputs
  inherit (result) validatedConfig orderedCharts generatedCharts combinedYaml;

  # Verify structure
  chartCount = builtins.length result.generatedCharts;
  hasOrderedCharts = result.orderedCharts != [];
  hasCombinedYaml = result.combinedYaml != "";

  # Individual chart access
  service1Chart = result.charts.service1;
  service2Chart = result.charts.service2;
}