# Complex Multi-Chart Example with Shared Resources
# Demonstrates advanced multi-chart features including shared resources

let
  nix-helm = import ../lib { };

  # Database service with persistent storage
  databaseService = {
    name = "postgres-db";
    version = "1.0.0";
    description = "PostgreSQL database with persistent storage";

    app = {
      name = "postgres";
      image = "postgres:15";
      ports = [5432];
      env = [
        { name = "POSTGRES_DB"; value = "appdb"; }
        { name = "POSTGRES_USER"; value = "appuser"; }
        { name = "POSTGRES_PASSWORD"; valueFrom.secretKeyRef = { name = "db-credentials"; key = "password"; }; }
      ];
    };

    resources = {
      deployment = {
        replicas = 1;
        resources = {
          requests = { memory = "256Mi"; cpu = "100m"; };
          limits = { memory = "512Mi"; cpu = "500m"; };
        };
      };

      service = {
        type = "ClusterIP";
        ports = [{ port = 5432; targetPort = 5432; }];
      };

      pvc = {
        name = "postgres-data";
        size = "10Gi";
        storageClass = "standard";
        accessModes = ["ReadWriteOnce"];
      };
    };

    security = {
      podSecurityContext = {
        fsGroup = 999;
        runAsUser = 999;
        runAsGroup = 999;
      };
    };
  };

  # Backend API service
  backendService = {
    name = "backend-api";
    version = "1.0.0";
    description = "Backend API service with database connectivity";

    app = {
      name = "backend";
      image = "nginx:alpine"; # Using nginx for demo
      ports = [8080];
      env = [
        { name = "DATABASE_URL"; value = "postgresql://appuser:password@postgres-db:5432/appdb"; }
        { name = "REDIS_URL"; value = "redis://redis-cache:6379"; }
        { name = "APP_CONFIG"; valueFrom.configMapKeyRef = { name = "app-config"; key = "config.yaml"; }; }
      ];
    };

    resources = {
      deployment = {
        replicas = 2;
        resources = {
          requests = { memory = "128Mi"; cpu = "50m"; };
          limits = { memory = "256Mi"; cpu = "200m"; };
        };
      };

      service = {
        type = "ClusterIP";
        ports = [{ port = 8080; targetPort = 8080; }];
      };

      hpa = {
        minReplicas = 2;
        maxReplicas = 5;
        targetCPUUtilizationPercentage = 70;
      };
    };
  };

  # Frontend service
  frontendService = {
    name = "frontend-app";
    version = "1.0.0";
    description = "Frontend web application";

    app = {
      name = "frontend";
      image = "nginx:alpine";
      ports = [80];
      env = [
        { name = "API_BASE_URL"; value = "http://backend-api:8080/api"; }
      ];
    };

    resources = {
      deployment = {
        replicas = 3;
        resources = {
          requests = { memory = "64Mi"; cpu = "25m"; };
          limits = { memory = "128Mi"; cpu = "100m"; };
        };
      };

      service = {
        type = "LoadBalancer";
        ports = [{ port = 80; targetPort = 80; }];
      };

      ingress = {
        enabled = true;
        className = "nginx";
        hosts = [
          {
            host = "myapp.example.com";
            paths = [
              {
                path = "/";
                pathType = "Prefix";
                service = {
                  name = "frontend-app";
                  port = { number = 80; };
                };
              }
            ];
          }
        ];
        tls = [
          {
            secretName = "myapp-tls";
            hosts = ["myapp.example.com"];
          }
        ];
      };
    };
  };

  # Redis cache service
  redisService = {
    name = "redis-cache";
    version = "1.0.0";
    description = "Redis cache service";

    app = {
      name = "redis";
      image = "redis:7-alpine";
      ports = [6379];
    };

    resources = {
      deployment = {
        replicas = 1;
        resources = {
          requests = { memory = "128Mi"; cpu = "50m"; };
          limits = { memory = "256Mi"; cpu = "200m"; };
        };
      };

      service = {
        type = "ClusterIP";
        ports = [{ port = 6379; targetPort = 6379; }];
      };
    };
  };

in
# Multi-chart configuration with shared resources
{
  name = "complex-microservices-app";
  version = "1.0.0";
  description = "Complex microservices application with shared resources";

  charts = {
    inherit databaseService backendService frontendService redisService;
  };

  dependencies = [
    { name = "databaseService"; condition = "database.enabled"; }
    { name = "redisService"; condition = "redis.enabled"; }
    { name = "backendService"; condition = "backend.enabled"; }
    { name = "frontendService"; condition = "frontend.enabled"; }
  ];

  global = {
    namespace = "production";
    imageRegistry = "myregistry.com";
    labels = {
      "app.kubernetes.io/managed-by" = "nix-helm-generator";
      "app.kubernetes.io/part-of" = "complex-microservices-app";
      "environment" = "production";
    };
  };

  # Shared resources across all charts
  shared = {
    appName = "complex-microservices-app";
    namespace = "production";

    resources = [
      # Shared namespace
      {
        type = "namespace";
        name = "production";
        labels = {
          "name" = "production";
          "environment" = "prod";
          "team" = "platform";
        };
        annotations = {
          "description" = "Production namespace for complex microservices app";
        };
      }

      # Database credentials secret
      {
        type = "secret";
        name = "db-credentials";
        data = {
          password = "cGFzc3dvcmQ="; # base64 encoded "password"
          username = "YXBwdXNlcg=="; # base64 encoded "appuser"
        };
      }

      # Application configuration
      {
        type = "configmap";
        name = "app-config";
        data = {
          "config.yaml" = ''
            app:
              name: complex-microservices-app
              version: 1.0.0
              environment: production
            database:
              host: postgres-db
              port: 5432
              database: appdb
            redis:
              host: redis-cache
              port: 6379
            logging:
              level: info
          '';
          "nginx.conf" = ''
            server {
                listen 80;
                server_name localhost;
                location / {
                    proxy_pass http://backend-api:8080;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                }
            }
          '';
        };
      }

      # Service account for backend
      {
        type = "serviceaccount";
        name = "backend-sa";
      }

      # RBAC for backend service
      {
        type = "rbac";
        name = "backend-rbac";
        rules = [
          {
            apiGroups = [""];
            resources = ["pods" "services" "configmaps" "secrets"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["apps"];
            resources = ["deployments" "replicasets"];
            verbs = ["get" "list" "watch" "update"];
          }
        ];
        subjects = [
          {
            kind = "ServiceAccount";
            name = "backend-sa";
            namespace = "production";
          }
        ];
      }
    ];
  };
}