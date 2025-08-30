{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib/default.nix { inherit lib; };

  # Nginx configuration
  nginxConfig = {
    name = "nginx";
    version = "1.0.0";
    description = "A Helm chart for Nginx web server";
    appVersion = "1.25.0";

    app = {
      image = "nginx:1.25.0";
      ports = [80 443];

      # Environment variables
      env = {
        NGINX_PORT = "80";
      };

      # Configuration data
      configData = {
        "nginx.conf" = ''
          events {
            worker_connections 1024;
          }
          http {
            server {
              listen 80;
              location / {
                return 200 "Hello from Nginx!\n";
              }
            }
          }
        '';
      };

      # Ingress configuration
      ingress = {
        enabled = true;
        hosts = ["nginx.example.com"];
        annotations = {
          "kubernetes.io/ingress.class" = "nginx";
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        };
        tls = [
          {
            secretName = "nginx-tls";
            hosts = ["nginx.example.com"];
          }
        ];
      };

      # Production configuration
      production = {
        # Resource limits and requests
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

        # Health checks
        healthChecks = {
          readinessProbe = {
            httpGet = {
              path = "/";
              port = 80;
            };
            initialDelaySeconds = 5;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/";
              port = 80;
            };
            initialDelaySeconds = 30;
            periodSeconds = 30;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 101;
            runAsGroup = 101;
            fsGroup = 101;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = true;
            runAsNonRoot = true;
            runAsUser = 101;
          };
        };

        # Pod Disruption Budget
        pdb = {
          enabled = true;
          minAvailable = "50%";
        };

        # Network Policy
        networkPolicy = {
          enabled = true;
          ingress = [
            {
              from = [
                {
                  namespaceSelector = {
                    matchLabels = {
                      name = "ingress-nginx";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 80;
                  protocol = "TCP";
                }
                {
                  port = 443;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["nginx" "web-server" "http" "proxy"];
    home = "https://nginx.org";
    sources = ["https://github.com/nginx/nginx"];
    maintainers = [
      {
        name = "Nginx Maintainers";
        email = "nginx@nginx.org";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart nginxConfig