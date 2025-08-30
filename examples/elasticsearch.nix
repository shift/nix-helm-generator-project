{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib/default.nix { inherit lib; };

  # Elasticsearch configuration
  elasticsearchConfig = {
    name = "elasticsearch";
    version = "1.0.0";
    description = "A Helm chart for Elasticsearch search and analytics engine";
    appVersion = "8.11.0";

    app = {
      image = "elasticsearch:8.11.0";
      ports = [9200 9300];

      # Environment variables
      env = {
        ES_JAVA_OPTS = "-Xms1g -Xmx1g";
        discovery.type = "single-node";
        xpack.security.enabled = "false";  # Disable security for simplicity
        xpack.monitoring.enabled = "false";
        xpack.graph.enabled = "false";
        xpack.watcher.enabled = "false";
        xpack.ml.enabled = "false";
      };

      # Configuration data
      configData = {
        "elasticsearch.yml" = ''
          cluster.name: elasticsearch
          node.name: elasticsearch-node
          path.data: /usr/share/elasticsearch/data
          path.logs: /usr/share/elasticsearch/logs
          network.host: 0.0.0.0
          http.port: 9200
          discovery.type: single-node
          xpack.security.enabled: false
          xpack.monitoring.enabled: false
          xpack.graph.enabled: false
          xpack.watcher.enabled: false
          xpack.ml.enabled: false

          # Memory and performance settings
          bootstrap.memory_lock: false
          indices.query.bool.max_clause_count: 1024
          indices.memory.index_buffer_size: 10%
          indices.memory.min_index_buffer_size: 48mb
          indices.memory.max_index_buffer_size: 10%

          # Thread pools
          thread_pool.search.size: 3
          thread_pool.search.queue_size: 1000
          thread_pool.index.size: 1
          thread_pool.index.queue_size: 1000
          thread_pool.bulk.size: 2
          thread_pool.bulk.queue_size: 1000

          # Circuit breaker
          indices.breaker.total.limit: 70%
          indices.breaker.fielddata.limit: 60%
          indices.breaker.request.limit: 60%

          # Logging
          logger.level: INFO
          logger.org.elasticsearch.discovery: DEBUG
        '';

        "jvm.options" = ''
          -Xms1g
          -Xmx1g
          -XX:+UseG1GC
          -XX:MaxGCPauseMillis=200
          -XX:+UnlockExperimentalVMOptions
          -XX:+UseCGroupMemoryLimitForHeap
          -XX:MaxRAMFraction=1
          -XX:+PrintGCDetails
          -XX:+PrintGCDateStamps
          -XX:+PrintTenuringDistribution
          -XX:+PrintGCApplicationStoppedTime
          -XX:+UseGCLogFileRotation
          -XX:NumberOfGCLogFiles=32
          -XX:GCLogFileSize=64m
          -Xloggc:/usr/share/elasticsearch/logs/gc.log
          -XX:+HeapDumpOnOutOfMemoryError
          -XX:HeapDumpPath=/usr/share/elasticsearch/logs
          -XX:ErrorFile=/usr/share/elasticsearch/logs/hs_err_pid%p.log
          -XX:+PrintClassHistogram
        '';
      };

      # Production configuration
      production = {
        # Resource limits and requests
        resources = {
          requests = {
            cpu = "1000m";
            memory = "2Gi";
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
              path = "/_cluster/health";
              port = 9200;
            };
            initialDelaySeconds = 30;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/_cluster/health";
              port = 9200;
            };
            initialDelaySeconds = 60;
            periodSeconds = 30;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 1000;
            runAsGroup = 1000;
            fsGroup = 1000;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = false;  # Elasticsearch needs to write to data directory
            runAsNonRoot = true;
            runAsUser = 1000;
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
                      app = "elasticsearch-client";
                    };
                  };
                }
                {
                  namespaceSelector = {
                    matchLabels = {
                      name = "logging";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 9200;
                  protocol = "TCP";
                }
                {
                  port = 9300;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["elasticsearch" "search" "analytics" "logstash" "kibana"];
    home = "https://elastic.co";
    sources = ["https://github.com/elastic/elasticsearch"];
    maintainers = [
      {
        name = "Elastic";
        email = "info@elastic.co";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart elasticsearchConfig