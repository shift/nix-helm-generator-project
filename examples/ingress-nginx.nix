{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # Ingress-nginx configuration
  ingressNginxConfig = {
    name = "ingress-nginx";
    version = "1.0.0";
    description = "A Helm chart for NGINX Ingress Controller";
    appVersion = "1.8.1";

    app = {
      image = "k8s.gcr.io/ingress-nginx/controller:v1.8.1";
      ports = [80 443];

      # Environment variables
      env = {
        POD_NAME = "ingress-nginx-controller";
        POD_NAMESPACE = "ingress-nginx";
      };

      # Configuration data
      configData = {
        "nginx.conf" = ''
          worker_processes auto;
          worker_rlimit_nofile 14600;

          events {
            worker_connections 1024;
            use epoll;
            multi_accept on;
          }

          http {
            sendfile on;
            tcp_nopush on;
            tcp_nodelay on;
            keepalive_timeout 65;
            types_hash_max_size 2048;
            client_max_body_size 100M;

            include /etc/nginx/mime.types;
            default_type application/octet-stream;

            log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_x_forwarded_for"';

            access_log /var/log/nginx/access.log main;
            error_log /var/log/nginx/error.log;

            gzip on;
            gzip_vary on;
            gzip_min_length 1000;
            gzip_proxied any;
            gzip_comp_level 6;
            gzip_types
              text/plain
              text/css
              text/xml
              text/javascript
              application/json
              application/javascript
              application/xml+rss
              application/atom+xml
              image/svg+xml;

            server {
              listen 80 default_server;
              listen [::]:80 default_server;
              server_name _;
              return 404;
            }

            server {
              listen 443 ssl http2 default_server;
              listen [::]:443 ssl http2 default_server;
              server_name _;
              return 404;
            }
          }
        '';

        "tcp-services-configmap.yaml" = ''
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: tcp-services
            namespace: ingress-nginx
          data: {}
        '';

        "udp-services-configmap.yaml" = ''
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: udp-services
            namespace: ingress-nginx
          data: {}
        '';
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
              path = "/healthz";
              port = 10254;
            };
            initialDelaySeconds = 10;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/healthz";
              port = 10254;
            };
            initialDelaySeconds = 10;
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
              from = [];
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
    keywords = ["ingress" "nginx" "controller" "kubernetes"];
    home = "https://kubernetes.github.io/ingress-nginx";
    sources = ["https://github.com/kubernetes/ingress-nginx"];
    maintainers = [
      {
        name = "Kubernetes Authors";
        email = "kubernetes-dev@googlegroups.com";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart ingressNginxConfig