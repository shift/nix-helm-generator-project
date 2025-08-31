# Example Multi-Chart Application
# This demonstrates a complete microservices stack with dependencies

let
  nix-helm = import ../lib { };

  # Database chart configuration
  databaseChart = {
    name = "postgres-db";
    version = "1.0.0";
    description = "PostgreSQL database service";

    app = {
      name = "postgres";
      image = "postgres:15";
      ports = [5432];
      env = [
        { name = "POSTGRES_DB"; value = "myapp"; }
        { name = "POSTGRES_USER"; value = "myapp"; }
        { name = "POSTGRES_PASSWORD"; valueFrom.secretKeyRef = { name = "db-secret"; key = "password"; }; }
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
        size = "10Gi";
        storageClass = "standard";
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

  # Backend API chart configuration
  backendChart = {
    name = "backend-api";
    version = "1.0.0";
    description = "Backend API service";

    app = {
      name = "backend";
      image = "myapp/backend:latest";
      ports = [8080];
      env = [
        { name = "DATABASE_URL"; value = "postgresql://myapp:myapp@postgres-db:5432/myapp"; }
        { name = "REDIS_URL"; value = "redis://redis-service:6379"; }
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
        maxReplicas = 10;
        targetCPUUtilizationPercentage = 70;
      };
    };

    security = {
      podSecurityContext = {
        runAsNonRoot = true;
        runAsUser = 1000;
      };
    };
  };

  # Frontend chart configuration
  frontendChart = {
    name = "frontend-app";
    version = "1.0.0";
    description = "Frontend web application";

    app = {
      name = "frontend";
      image = "myapp/frontend:latest";
      ports = [80];
      env = [
        { name = "API_URL"; value = "http://backend-api:8080"; }
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
      };
    };
  };

  # Redis cache chart configuration
  redisChart = {
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
# Multi-chart configuration
{
  name = "my-microservices-app";
  version = "1.0.0";
  description = "Complete microservices application stack";

  charts = {
    inherit databaseChart backendChart frontendChart redisChart;
  };

  dependencies = [
    { name = "databaseChart"; condition = "database.enabled"; }
    { name = "redisChart"; condition = "redis.enabled"; }
    { name = "backendChart"; condition = "backend.enabled"; }
    { name = "frontendChart"; condition = "frontend.enabled"; }
  ];

  global = {
    namespace = "production";
    imageRegistry = "myregistry.com";
    labels = {
      "app.kubernetes.io/managed-by" = "nix-helm-generator";
      "app.kubernetes.io/part-of" = "my-microservices-app";
    };
  };

  # Shared resources across all charts
  shared = {
    resources = [
      {
        type = "namespace";
        name = "production";
        labels = {
          "name" = "production";
          "environment" = "prod";
        };
      }
      {
        type = "secret";
        name = "db-secret";
        namespace = "production";
        data = {
          password = "cGFzc3dvcmQ="; # base64 encoded "password"
        };
      }
      {
        type = "configmap";
        name = "app-config";
        namespace = "production";
        data = {
          "log-level" = "info";
          "environment" = "production";
        };
      }
    ];
  };
}