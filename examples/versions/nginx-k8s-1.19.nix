{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../../lib/default.nix { inherit lib; };

  # Nginx configuration for Kubernetes 1.19
  nginxConfig = {
    name = "nginx-k8s-1-19";
    version = "1.0.0";
    description = "Nginx for Kubernetes 1.19 (uses networking.k8s.io/v1beta1)";
    appVersion = "1.21.0";
    kubernetesVersion = "1.19.0";  # This will trigger v1beta1 API versions

    app = {
      image = "nginx:1.21.0";
      ports = [80 443];

      env = {
        NGINX_PORT = "80";
      };

      configData = {
        "nginx.conf" = ''
          events {
            worker_connections 1024;
          }
          http {
            server {
              listen 80;
              location / {
                return 200 "Hello from Nginx (K8s 1.19)!\n";
              }
            }
          }
        '';
      };

      ingress = {
        enabled = true;
        hosts = ["nginx-k8s-1-19.example.com"];
        annotations = {
          "kubernetes.io/ingress.class" = "nginx";
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        };
        tls = [
          {
            secretName = "nginx-k8s-1-19-tls";
            hosts = ["nginx-k8s-1-19.example.com"];
          }
        ];
      };

      production = {
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

        pdb = {
          enabled = true;
          minAvailable = "50%";
        };

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

    keywords = ["nginx" "web-server" "http" "proxy" "k8s-1.19"];
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