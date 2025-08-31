{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # PostgreSQL configuration with advanced features
  postgresConfig = {
    name = "postgres-enhanced";
    version = "1.0.0";
    description = "Enhanced PostgreSQL deployment with persistence, RBAC, and monitoring";
    appVersion = "15.4";
    kubernetesVersion = "1.25.0";

    app = {
      image = "postgres:15.4";
      ports = [5432];

      # Environment variables
      env = {
        POSTGRES_DB = "mydb";
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "changeme";  # In production, use secrets
        PGDATA = "/var/lib/postgresql/data";
      };

      # Configuration data
      configData = {
        "postgresql.conf" = ''
          listen_addresses = '*'
          port = 5432
          max_connections = 100
          shared_buffers = 128MB
          effective_cache_size = 256MB
          maintenance_work_mem = 32MB
          checkpoint_completion_target = 0.9
          wal_buffers = 16MB
          default_statistics_target = 100
          random_page_cost = 1.1
          effective_io_concurrency = 200
          work_mem = 4MB
          min_wal_size = 1GB
          max_wal_size = 4GB
          max_worker_processes = 2
          max_parallel_workers_per_gather = 1
          max_parallel_workers = 2
          max_parallel_maintenance_workers = 1
        '';
        "pg_hba.conf" = ''
          local all postgres peer
          local all all md5
          host all all 127.0.0.1/32 md5
          host all all ::1/128 md5
          local replication all peer
          host replication all 127.0.0.1/32 md5
          host replication all ::1/128 md5
        '';
      };

      # RBAC configuration
      rbac = {
        serviceAccount = {
          enabled = true;
          name = "postgres-sa";
          annotations = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/postgres-role";
          };
        };
        role = {
          enabled = true;
          name = "postgres-role";
          rules = [
            {
              apiGroups = [""];
              resources = ["pods" "services" "endpoints"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["apps"];
              resources = ["statefulsets"];
              verbs = ["get" "list" "watch" "update" "patch"];
            }
          ];
        };
        roleBinding = {
          enabled = true;
          name = "postgres-rolebinding";
          roleName = "postgres-role";
          serviceAccountName = "postgres-sa";
        };
      };

      # StatefulSet configuration
      statefulSet = {
        enabled = true;
        replicas = 1;
        serviceName = "postgres-headless";
        storageClassName = "gp3";
        storageSize = "50Gi";
      };

      # Persistent Volume Claim
      persistentVolumeClaim = {
        enabled = true;
        name = "postgres-pvc";
        storageClassName = "gp3";
        storageSize = "50Gi";
        accessModes = ["ReadWriteOnce"];
      };

      # Secret for sensitive data
      secret = {
        enabled = true;
        name = "postgres-secret";
        type = "Opaque";
        stringData = {
          POSTGRES_PASSWORD = "changeme";
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "mydb";
        };
      };

      # Monitoring configuration
      monitoring = {
        serviceMonitor = {
          enabled = true;
          name = "postgres-servicemonitor";
          selectorLabels = {
            app = "postgres-enhanced";
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
            memory = "512Mi";
          };
          limits = {
            cpu = "1000m";
            memory = "1Gi";
          };
        };

        # Health checks
        healthChecks = {
          readinessProbe = {
            exec = {
              command = ["pg_isready" "-U" "postgres" "-d" "mydb"];
            };
            initialDelaySeconds = 15;
            periodSeconds = 10;
            timeoutSeconds = 5;
            successThreshold = 1;
            failureThreshold = 6;
          };
          livenessProbe = {
            exec = {
              command = ["pg_isready" "-U" "postgres" "-d" "mydb"];
            };
            initialDelaySeconds = 30;
            periodSeconds = 10;
            timeoutSeconds = 5;
            successThreshold = 1;
            failureThreshold = 6;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 999;
            runAsGroup = 999;
            fsGroup = 999;
            runAsNonRoot = true;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = false;  # PostgreSQL needs to write to /var/lib/postgresql/data
            runAsNonRoot = true;
            runAsUser = 999;
            runAsGroup = 999;
            capabilities = {
              drop = ["ALL"];
            };
          };
        };

        # Pod Disruption Budget
        pdb = {
          enabled = true;
          minAvailable = 1;
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
                      app = "postgres-client";
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
                  port = 5432;
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
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["postgresql" "database" "sql" "postgres"];
    home = "https://postgresql.org";
    sources = ["https://github.com/postgres/postgres"];
    maintainers = [
      {
        name = "PostgreSQL Community";
        email = "pgsql-general@postgresql.org";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart postgresConfig