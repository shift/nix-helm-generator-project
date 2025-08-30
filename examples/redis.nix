{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # Redis configuration
  redisConfig = {
    name = "redis";
    version = "1.0.0";
    description = "A Helm chart for Redis in-memory database";
    appVersion = "7.2.0";

    app = {
      image = "redis:7.2.0";
      ports = [6379];

      # Environment variables
      env = {
        REDIS_PASSWORD = "changeme";  # In production, use secrets
        REDIS_DISABLE_COMMANDS = "FLUSHDB,FLUSHALL";
      };

      # Configuration data
      configData = {
        "redis.conf" = ''
          bind 0.0.0.0
          port 6379
          timeout 0
          tcp-keepalive 300
          daemonize no
          supervised no
          loglevel notice
          databases 16
          save 900 1
          save 300 10
          save 60 10000
          stop-writes-on-bgsave-error yes
          rdbcompression yes
          rdbchecksum yes
          dbfilename dump.rdb
          dir /data
          slave-serve-stale-data yes
          slave-read-only yes
          repl-diskless-sync no
          repl-diskless-sync-delay 5
          slave-priority 100
          appendonly yes
          appendfilename "appendonly.aof"
          appendfsync everysec
          no-appendfsync-on-rewrite no
          auto-aof-rewrite-percentage 100
          auto-aof-rewrite-min-size 64mb
          lua-time-limit 5000
          slowlog-log-slower-than 10000
          slowlog-max-len 128
          notify-keyspace-events ""
          hash-max-ziplist-entries 512
          hash-max-ziplist-value 64
          list-max-ziplist-size -2
          list-compress-depth 0
          set-max-intset-entries 512
          zset-max-ziplist-entries 128
          zset-max-ziplist-value 64
          hll-sparse-max-bytes 3000
          activerehashing yes
          client-output-buffer-limit normal 0 0 0
          client-output-buffer-limit slave 256mb 64mb 60
          client-output-buffer-limit pubsub 32mb 8mb 60
          hz 10
          aof-rewrite-incremental-fsync yes
        '';
      };

      # Production configuration
      production = {
        # Resource limits and requests
        resources = {
          requests = {
            cpu = "200m";
            memory = "256Mi";
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
              command = ["redis-cli" "ping"];
            };
            initialDelaySeconds = 5;
            periodSeconds = 10;
          };
          livenessProbe = {
            exec = {
              command = ["redis-cli" "ping"];
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
            readOnlyRootFilesystem = false;  # Redis needs to write to /data
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
                      app = "redis-client";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 6379;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["redis" "database" "cache" "key-value"];
    home = "https://redis.io";
    sources = ["https://github.com/redis/redis"];
    maintainers = [
      {
        name = "Redis Labs";
        email = "redis@redis.io";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart redisConfig