let
  nix-helm-generator = import ./lib {};
  lib = import <nixpkgs> {}.lib;
in
let
  # Create a complex chart with many production features
  largeChart = nix-helm-generator.mkChart {
    name = "large-app";
    version = "1.0.0";
    description = "Large test application with complex production features";

    app = {
      image = "nginx:alpine";
      replicas = 10;
      ports = lib.range 8000 8010;  # Many ports

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
              port = 8000;
            };
            initialDelaySeconds = 5;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/health";
              port = 8000;
            };
            initialDelaySeconds = 30;
            periodSeconds = 30;
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

        networkPolicy = {
          enabled = true;
          ingress = [
            {
              from = [
                {
                  podSelector = {
                    matchLabels = { app = "large-app"; };
                  };
                }
              ];
            }
          ];
        };
      };
    };
  };

in
{
  chartGenerated = largeChart ? yamlOutput;
  yamlLength = lib.length (lib.splitString "\n" largeChart.yamlOutput);
  hasMultipleServices = lib.any (line: lib.hasPrefix "kind: Deployment" line) (lib.splitString "\n" largeChart.yamlOutput);
}