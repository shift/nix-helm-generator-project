{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # PostgreSQL configuration
  postgresConfig = {
    name = "postgres";
    version = "1.0.0";
    description = "A Helm chart for PostgreSQL database";
    appVersion = "15.4";

    app = {
      image = "postgres:15.4";
      ports = [5432];

      # Environment variables
      env = {
        POSTGRES_DB = "postgres";
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "changeme";  # In production, use secrets
        PGDATA = "/var/lib/postgresql/data/pgdata";
      };

      # Configuration data
      configData = {
        "postgresql.conf" = ''
          # Connection settings
          listen_addresses = '*'
          port = 5432
          max_connections = 100

          # Memory settings
          shared_buffers = 128MB
          effective_cache_size = 1GB
          work_mem = 4MB
          maintenance_work_mem = 64MB

          # Checkpoint settings
          checkpoint_segments = 32
          checkpoint_completion_target = 0.9
          wal_buffers = 16MB
          default_statistics_target = 100

          # Logging
          log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
          log_statement = 'ddl'
          log_duration = on
          log_lock_waits = on
          log_min_duration_statement = 1000

          # Autovacuum
          autovacuum = on
          autovacuum_max_workers = 3
          autovacuum_naptime = 20s
          autovacuum_vacuum_threshold = 50
          autovacuum_analyze_threshold = 50
          autovacuum_vacuum_scale_factor = 0.02
          autovacuum_analyze_scale_factor = 0.01

          # Other settings
          random_page_cost = 1.1
          effective_io_concurrency = 200
        '';

        "pg_hba.conf" = ''
          # TYPE  DATABASE        USER            ADDRESS                 METHOD
          local   all             postgres                                trust
          local   all             all                                     trust
          host    all             all             127.0.0.1/32            trust
          host    all             all             ::1/128                 trust
          host    all             all             0.0.0.0/0               md5
        '';
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
            cpu = "2000m";
            memory = "2Gi";
          };
        };

        # Health checks
        healthChecks = {
          readinessProbe = {
            exec = {
              command = ["pg_isready" "-U" "postgres"];
            };
            initialDelaySeconds = 15;
            periodSeconds = 10;
          };
          livenessProbe = {
            exec = {
              command = ["pg_isready" "-U" "postgres"];
            };
            initialDelaySeconds = 30;
            periodSeconds = 30;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 999;
            runAsGroup = 999;
            fsGroup = 999;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = false;  # PostgreSQL needs to write to /var/lib/postgresql/data
            runAsNonRoot = true;
            runAsUser = 999;
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
              ];
              ports = [
                {
                  port = 5432;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["postgres" "postgresql" "database" "sql"];
    home = "https://postgresql.org";
    sources = ["https://github.com/postgres/postgres"];
    maintainers = [
      {
        name = "PostgreSQL Global Development Group";
        email = "pgsql-bugs@postgresql.org";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart postgresConfig