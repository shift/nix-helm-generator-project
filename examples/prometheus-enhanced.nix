{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # Prometheus configuration with advanced features
  prometheusConfig = {
    name = "prometheus-enhanced";
    version = "1.0.0";
    description = "Enhanced Prometheus monitoring stack with persistence and security";
    appVersion = "2.45.0";
    kubernetesVersion = "1.25.0";

    app = {
      image = "prom/prometheus:v2.45.0";
      ports = [9090];

      # Environment variables
      env = {
        PROMETHEUS_CONFIG = "/etc/prometheus/prometheus.yml";
        PROMETHEUS_STORAGE_PATH = "/prometheus";
        PROMETHEUS_RETENTION_TIME = "30d";
        PROMETHEUS_RETENTION_SIZE = "50GB";
      };

      # Configuration data
      configData = {
        "prometheus.yml" = ''
          global:
            scrape_interval: 15s
            evaluation_interval: 15s
            external_labels:
              cluster: "production"
              region: "us-west-2"

          rule_files:
            - /etc/prometheus/rules/*.yml

          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

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
                  target_label: kubernetes_namespace
                - source_labels: [__meta_kubernetes_pod_name]
                  action: replace
                  target_label: kubernetes_pod_name
        '';
      };

      # RBAC configuration
      rbac = {
        serviceAccount = {
          enabled = true;
          name = "prometheus-sa";
          annotations = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/prometheus-role";
          };
        };
        role = {
          enabled = true;
          name = "prometheus-role";
          rules = [
            {
              apiGroups = [""];
              resources = ["nodes" "nodes/proxy" "services" "endpoints" "pods"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["networking.k8s.io"];
              resources = ["ingresses"];
              verbs = ["get" "list" "watch"];
            }
          ];
        };
        roleBinding = {
          enabled = true;
          name = "prometheus-rolebinding";
          roleName = "prometheus-role";
          serviceAccountName = "prometheus-sa";
        };
      };

      # StatefulSet configuration
      statefulSet = {
        enabled = true;
        replicas = 1;
        serviceName = "prometheus-headless";
        storageClassName = "gp3";
        storageSize = "100Gi";
      };

      # Persistent Volume Claim
      persistentVolumeClaim = {
        enabled = true;
        name = "prometheus-pvc";
        storageClassName = "gp3";
        storageSize = "100Gi";
        accessModes = ["ReadWriteOnce"];
      };

      # Secret for sensitive data
      secret = {
        enabled = true;
        name = "prometheus-secret";
        type = "Opaque";
        stringData = {
          PROMETHEUS_ADMIN_PASSWORD = "changeme";
        };
      };

      # Monitoring configuration (self-monitoring)
      monitoring = {
        serviceMonitor = {
          enabled = true;
          name = "prometheus-servicemonitor";
          selectorLabels = {
            app = "prometheus-enhanced";
          };
          endpoints = [
            {
              port = "http";
              path = "/metrics";
              interval = "30s";
              scrapeTimeout = "10s";
            }
          ];
        };
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
            timeoutSeconds = 5;
            successThreshold = 1;
            failureThreshold = 3;
          };
          livenessProbe = {
            httpGet = {
              path = "/-/healthy";
              port = 9090;
            };
            initialDelaySeconds = 300;
            periodSeconds = 30;
            timeoutSeconds = 10;
            successThreshold = 1;
            failureThreshold = 3;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 65534;
            runAsGroup = 65534;
            fsGroup = 65534;
            runAsNonRoot = true;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = false;  # Prometheus needs to write to /prometheus
            runAsNonRoot = true;
            runAsUser = 65534;
            runAsGroup = 65534;
            capabilities = {
              drop = ["ALL"];
            };
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
                      app = "grafana";
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
          egress = [
            {
              to = [
                {
                  podSelector = {
                    matchLabels = {
                      k8s-app = "kube-dns";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 53;
                  protocol = "UDP";
                }
                {
                  port = 53;
                  protocol = "TCP";
                }
              ];
            }
            {
              to = [];
              ports = [
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
    keywords = ["prometheus" "monitoring" "metrics" "observability"];
    home = "https://prometheus.io";
    sources = ["https://github.com/prometheus/prometheus"];
    maintainers = [
      {
        name = "Prometheus Community";
        email = "prometheus-developers@googlegroups.com";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart prometheusConfig