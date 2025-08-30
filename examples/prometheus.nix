{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib/default.nix { inherit lib; };

  # Prometheus configuration
  prometheusConfig = {
    name = "prometheus";
    version = "1.0.0";
    description = "A Helm chart for Prometheus monitoring system";
    appVersion = "2.45.0";

    app = {
      image = "prom/prometheus:v2.45.0";
      ports = [9090];

      # Environment variables
      env = {
        PROMETHEUS_CONFIG = "/etc/prometheus/prometheus.yml";
        PROMETHEUS_STORAGE_PATH = "/prometheus";
      };

      # Configuration data
      configData = {
        "prometheus.yml" = ''
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          rule_files:
            # - "first_rules.yml"
            # - "second_rules.yml"

          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

            - job_name: 'node-exporter'
              static_configs:
                - targets: ['node-exporter:9100']

            - job_name: 'kube-state-metrics'
              static_configs:
                - targets: ['kube-state-metrics:8080']

            - job_name: 'kubernetes-apiservers'
              kubernetes_sd_configs:
                - role: endpoints
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
              relabel_configs:
                - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
                  action: keep
                  regex: default;kubernetes;https

            - job_name: 'kubernetes-nodes'
              kubernetes_sd_configs:
                - role: node
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
              relabel_configs:
                - action: labelmap
                  regex: __meta_kubernetes_node_label_(.+)
                - target_label: __address__
                  replacement: kubernetes.default.svc:443
                - source_labels: [__meta_kubernetes_node_name]
                  regex: (.+)
                  target_label: __metrics_path__
                  replacement: /api/v1/nodes/$1/proxy/metrics

            - job_name: 'kubernetes-pods'
              kubernetes_sd_configs:
                - role: pod
              relabel_configs:
                - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
                  action: keep
                  regex: true
                - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
                  action: replace
                  target_label: __metrics_path__
                  regex: (.+)
                - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
                  action: replace
                  regex: ([^:]+)(?::\d+)?;(\d+)
                  replacement: $1:$2
                  target_label: __address__
                - action: labelmap
                  regex: __meta_kubernetes_pod_label_(.+)
                - source_labels: [__meta_kubernetes_namespace]
                  action: replace
                  target_label: namespace
                - source_labels: [__meta_kubernetes_pod_name]
                  action: replace
                  target_label: pod
        '';
      };

      # Production configuration
      production = {
        # Resource limits and requests
        resources = {
          requests = {
            cpu = "500m";
            memory = "1Gi";
          };
          limits = {
            cpu = "2000m";
            memory = "4Gi";
          };
        };

        # Health checks
        healthChecks = {
          readinessProbe = {
            httpGet = {
              path = "/-/ready";
              port = 9090;
            };
            initialDelaySeconds = 30;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/-/healthy";
              port = 9090;
            };
            initialDelaySeconds = 30;
            periodSeconds = 30;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 65534;
            runAsGroup = 65534;
            fsGroup = 65534;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = true;
            runAsNonRoot = true;
            runAsUser = 65534;
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
                  podSelector = {
                    matchLabels = {
                      app = "prometheus-client";
                    };
                  };
                }
                {
                  namespaceSelector = {
                    matchLabels = {
                      name = "monitoring";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 9090;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["prometheus" "monitoring" "metrics" "observability"];
    home = "https://prometheus.io";
    sources = ["https://github.com/prometheus/prometheus"];
    maintainers = [
      {
        name = "The Prometheus Authors";
        email = "prometheus-developers@googlegroups.com";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart prometheusConfig