# Best Practices for Nix Helm Generator

This guide outlines recommended practices for using the Nix Helm Generator module effectively in production environments.

## Table of Contents

- [Project Structure](#project-structure)
- [Configuration Management](#configuration-management)
- [Security Practices](#security-practices)
- [Resource Management](#resource-management)
- [Monitoring and Observability](#monitoring-and-observability)
- [CI/CD Integration](#cicd-integration)
- [Testing Strategies](#testing-strategies)
- [Performance Optimization](#performance-optimization)

## Project Structure

### Recommended Directory Layout

```
my-helm-charts/
├── flake.nix                    # Nix flake configuration
├── flake.lock                   # Lock file
├── lib/                         # Custom library functions
├── charts/                      # Chart definitions
│   ├── base/                   # Base configurations
│   │   ├── web-app.nix        # Base web app config
│   │   └── api-app.nix        # Base API app config
│   ├── overlays/              # Environment-specific overlays
│   │   ├── development/       # Dev environment configs
│   │   ├── staging/           # Staging environment configs
│   │   └── production/        # Production environment configs
│   └── examples/              # Usage examples
├── tests/                      # Test files
├── docs/                       # Documentation
└── scripts/                    # Utility scripts
```

### Chart Organization

```nix
# charts/base/web-app.nix
let
  nix-helm-generator = import ../../lib {};
in
{
  # Base web application configuration
  name = "web-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    ports = [80];
  };
}
```

```nix
# charts/overlays/production/web-app.nix
let
  base = import ../../base/web-app.nix;
  nix-helm-generator = import ../../../lib {};
in
nix-helm-generator.mkChart (base // {
  app = base.app // {
    replicas = 5;

    production = {
      resources = {
        requests = { cpu = "200m"; memory = "256Mi"; };
        limits = { cpu = "1000m"; memory = "1Gi"; };
      };

      pdb = {
        enabled = true;
        minAvailable = 3;
      };
    };
  };
})
```

## Configuration Management

### Use Constants and Variables

```nix
# config/constants.nix
{
  # Application constants
  appName = "my-app";
  defaultNamespace = "default";

  # Environment-specific values
  environments = {
    development = {
      replicas = 1;
      imageTag = "latest";
    };
    staging = {
      replicas = 2;
      imageTag = "staging";
    };
    production = {
      replicas = 5;
      imageTag = "v1.0.0";
    };
  };

  # Common labels
  commonLabels = {
    managedBy = "nix-helm-generator";
    team = "platform";
  };
}
```

### Environment-Specific Configurations

```nix
# charts/web-app.nix
let
  nix-helm-generator = import ../lib {};
  constants = import ../config/constants.nix;

  # Get environment from build parameter or default
  env = builtins.getEnv "ENV" or "development";
  envConfig = constants.environments.${env};
in
nix-helm-generator.mkChart {
  name = "${constants.appName}-${env}";
  version = "1.0.0";
  namespace = env;

  labels = constants.commonLabels // {
    environment = env;
  };

  app = {
    image = "myapp:${envConfig.imageTag}";
    replicas = envConfig.replicas;
    ports = [80];

    env = {
      APP_ENV = env;
      LOG_LEVEL = if env == "development" then "DEBUG" else "INFO";
    };
  } // (if env == "production" then {
    production = {
      resources = {
        requests = { cpu = "100m"; memory = "128Mi"; };
        limits = { cpu = "500m"; memory = "512Mi"; };
      };
    };
  } else {});
}
```

### Configuration Validation

```nix
# lib/validators.nix
{
  # Validate environment configuration
  validateEnvironment = env: config:
    let
      requiredFields = ["replicas" "imageTag"];
      missingFields = builtins.filter (field: !config ? field) requiredFields;
    in
    if missingFields != [] then
      throw "Environment ${env} missing required fields: ${builtins.concatStringsSep ", " missingFields}"
    else
      config;

  # Validate resource limits
  validateResources = resources:
    let
      limits = resources.limits or {};
      requests = resources.requests or {};
    in
    if limits.cpu < requests.cpu then
      throw "CPU limit (${limits.cpu}) must be >= CPU request (${requests.cpu})"
    else if limits.memory < requests.memory then
      throw "Memory limit (${limits.memory}) must be >= memory request (${requests.memory})"
    else
      resources;
}
```

## Security Practices

### Security Context Configuration

```nix
# Always configure security contexts for production
app = {
  production = {
    securityContext = {
      pod = {
        runAsNonRoot = true;
        runAsUser = 101;      # nginx user
        runAsGroup = 101;     # nginx group
        fsGroup = 101;
        runAsGroup = 101;
      };

      container = {
        allowPrivilegeEscalation = false;
        readOnlyRootFilesystem = true;
        capabilities = {
          drop = ["ALL"];
          # Add only necessary capabilities
          add = ["NET_BIND_SERVICE"];  # If binding to privileged ports
        };
      };
    };
  };
}
```

### Network Policies

```nix
# Implement network segmentation
app = {
  production = {
    networkPolicy = {
      enabled = true;

      ingress = [
        # Allow traffic from web frontend
        {
          from = [
            {
              podSelector = {
                matchLabels = {
                  app = "web-frontend";
                  team = "platform";
                };
              };
            }
          ];
          ports = [
            { port = 80; protocol = "TCP"; }
            { port = 443; protocol = "TCP"; }
          ];
        }

        # Allow traffic from ingress controller
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
        }
      ];

      egress = [
        # Allow DNS resolution
        {
          to = [];
          ports = [
            { port = 53; protocol = "UDP"; }
            { port = 53; protocol = "TCP"; }
          ];
        }

        # Allow traffic to database
        {
          to = [
            {
              podSelector = {
                matchLabels = {
                  app = "postgres";
                };
              };
            }
          ];
          ports = [
            { port = 5432; protocol = "TCP"; }
          ];
        }
      ];
    };
  };
}
```

### Secret Management

```nix
# Use Kubernetes secrets instead of hardcoded values
let
  secrets = {
    database = {
      valueFrom = {
        secretKeyRef = {
          name = "db-secret";
          key = "password";
        };
      };
    };

    apiKey = {
      valueFrom = {
        secretKeyRef = {
          name = "api-secret";
          key = "key";
        };
      };
    };
  };
in
{
  app = {
    env = secrets // {
      DATABASE_HOST = "postgres.default.svc.cluster.local";
      REDIS_URL = "redis://redis.default.svc.cluster.local:6379";
    };
  };
}
```

## Resource Management

### Resource Quotas and Limits

```nix
# Set appropriate resource limits based on application needs
app = {
  production = {
    resources = {
      # Set requests to typical usage
      requests = {
        cpu = "100m";
        memory = "128Mi";
      };

      # Set limits to prevent resource exhaustion
      limits = {
        cpu = "500m";
        memory = "512Mi";
      };
    };
  };
}
```

### Pod Disruption Budgets

```nix
# Ensure high availability during cluster maintenance
app = {
  production = {
    pdb = {
      enabled = true;

      # For stateless applications
      minAvailable = "50%";

      # For stateful applications with odd number of replicas
      # minAvailable = 2;

      # Alternative: specify maximum unavailable
      # maxUnavailable = "25%";
    };
  };
}
```

### Horizontal Pod Autoscaling Considerations

```nix
# Design for HPA compatibility
app = {
  # Set appropriate resource requests for HPA calculations
  production = {
    resources = {
      requests = {
        cpu = "200m";    # Base CPU usage
        memory = "256Mi"; # Base memory usage
      };
    };
  };

  # Ensure metrics are available
  # metrics-server should be installed in the cluster
}
```

## Monitoring and Observability

### Health Checks

```nix
# Implement comprehensive health checks
app = {
  production = {
    healthChecks = {
      # Readiness probe - when pod is ready to receive traffic
      readinessProbe = {
        httpGet = {
          path = "/ready";
          port = 8080;
        };
        initialDelaySeconds = 10;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 3;
        successThreshold = 1;
      };

      # Liveness probe - when pod should be restarted
      livenessProbe = {
        httpGet = {
          path = "/health";
          port = 8080;
        };
        initialDelaySeconds = 30;
        periodSeconds = 30;
        timeoutSeconds = 5;
        failureThreshold = 3;
      };

      # Startup probe - for slow-starting applications
      startupProbe = {
        httpGet = {
          path = "/health";
          port = 8080;
        };
        initialDelaySeconds = 5;
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 6;
        successThreshold = 1;
      };
    };
  };
}
```

### Logging Configuration

```nix
# Configure structured logging
app = {
  env = {
    LOG_LEVEL = "INFO";
    LOG_FORMAT = "json";
    LOG_OUTPUT = "stdout";
  };

  # Mount config for log aggregation
  configData = {
    "logging.yaml" = ''
      version: 1
      disable_existing_loggers: false
      formatters:
        json:
          class: pythonjsonlogger.jsonlogger.JsonFormatter
          format: "%(asctime)s %(name)s %(levelname)s %(message)s"
      handlers:
        stdout:
          class: logging.StreamHandler
          formatter: json
          stream: ext://sys.stdout
      root:
        level: INFO
        handlers: [stdout]
    '';
  };
}
```

### Metrics and Monitoring

```nix
# Expose metrics endpoints
app = {
  ports = [8080 9090];  # Application port + metrics port

  production = {
    # Add annotations for monitoring
    annotations = {
      "prometheus.io/scrape" = "true";
      "prometheus.io/port" = "9090";
      "prometheus.io/path" = "/metrics";
    };
  };
}
```

## CI/CD Integration

### GitOps Integration

```bash
# Generate manifests for ArgoCD/Flux
#!/bin/bash
set -e

ENV=$1
OUTPUT_DIR="manifests/${ENV}"

# Generate manifests
mkdir -p "${OUTPUT_DIR}"
nix build ".#charts.${ENV}" --out-link "${OUTPUT_DIR}/result"

# Copy manifests to GitOps repository
cp -r "${OUTPUT_DIR}/result/"* "${GITOPS_REPO}/${ENV}/"

# Commit and push
cd "${GITOPS_REPO}"
git add .
git commit -m "Update ${ENV} manifests from nix-helm-generator"
git push
```

### CI Pipeline Integration

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v20
    - name: Validate charts
      run: |
        nix flake check
        nix build .#charts.production --dry-run

  deploy-staging:
    needs: validate
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v20
    - name: Deploy to staging
      run: |
        nix build .#charts.staging
        kubectl apply -f result/

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v20
    - name: Deploy to production
      run: |
        nix build .#charts.production
        kubectl apply -f result/
```

### Flake Configuration for CI/CD

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-helm-generator.url = "github:your-org/nix-helm-generator";
  };

  outputs = { self, nixpkgs, nix-helm-generator }:
    let
      system = "x86_64-linux";
      lib = nix-helm-generator.lib;

      # Chart configurations
      charts = {
        staging = import ./charts/staging.nix { inherit lib; };
        production = import ./charts/production.nix { inherit lib; };
      };

    in
    {
      # Build all charts
      packages.${system} = builtins.mapAttrs
        (name: config: lib.mkChart config)
        charts;

      # Development shell
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = [
          nix-helm-generator.packages.${system}.default
        ];
      };

      # Checks for CI
      checks.${system} = {
        validate-charts = nixpkgs.legacyPackages.${system}.runCommand "validate-charts" {} ''
          ${lib.validateChartConfig charts.production}
          echo "Charts are valid" > $out
        '';
      };
    };
}
```

## Testing Strategies

### Unit Tests

```nix
# tests/chart-test.nix
let
  nix-helm-generator = import ../lib {};

  # Test basic chart creation
  testBasicChart = let
    chart = nix-helm-generator.mkChart {
      name = "test-app";
      version = "1.0.0";
      app = { image = "nginx"; };
    };
  in
    assert chart ? yamlOutput;
    assert chart.chartMeta.name == "test-app";
    "Basic chart test passed";

  # Test validation
  testValidation = let
    result = builtins.tryEval (nix-helm-generator.mkChart {
      version = "1.0.0";
      # Missing name
    });
  in
    assert !result.success;
    "Validation test passed";

  # Test production features
  testProductionFeatures = let
    chart = nix-helm-generator.mkChart {
      name = "prod-app";
      version = "1.0.0";
      app = {
        image = "nginx";
        production = {
          resources = {
            requests = { cpu = "100m"; };
            limits = { cpu = "500m"; };
          };
        };
      };
    };
  in
    assert chart.k8sResources.deployment.spec.template.spec.containers[0].resources.requests.cpu == "100m";
    "Production features test passed";

in
{
  inherit testBasicChart testValidation testProductionFeatures;
}
```

### Integration Tests

```bash
#!/bin/bash
# tests/integration-test.sh

set -e

echo "Running integration tests..."

# Test chart generation
echo "Testing chart generation..."
nix build .#test-chart
echo "✓ Chart builds successfully"

# Test YAML validation
echo "Testing YAML validation..."
nix eval .#test-chart --json | jq -r '.yamlOutput' | kubectl apply --dry-run=client -f -
echo "✓ Generated YAML is valid Kubernetes"

# Test with different environments
echo "Testing environment configurations..."
for env in development staging production; do
  echo "Testing ${env} environment..."
  ENV=${env} nix build .#test-chart
  echo "✓ ${env} environment builds successfully"
done

echo "All integration tests passed!"
```

### Property-Based Testing

```nix
# tests/property-test.nix
let
  nix-helm-generator = import ../lib {};

  # Test that all generated resources have required labels
  testRequiredLabels = chartConfig: let
    chart = nix-helm-generator.mkChart chartConfig;
    deployment = chart.k8sResources.deployment;
    labels = deployment.metadata.labels;
  in
    assert labels ? app;
    assert labels.app == chartConfig.name;
    true;

  # Test that production features are applied correctly
  testProductionFeatures = config: let
    chart = nix-helm-generator.mkChart config;
    deployment = chart.k8sResources.deployment;
    containers = deployment.spec.template.spec.containers;
    mainContainer = builtins.head containers;
  in
    if config.app ? production && config.app.production ? resources then
      assert mainContainer ? resources;
      assert mainContainer.resources.requests.cpu == config.app.production.resources.requests.cpu;
      true
    else
      true;  # No production config, test passes

  # Test configurations
  testConfigs = [
    {
      name = "simple-app";
      version = "1.0.0";
      app = { image = "nginx"; };
    }
    {
      name = "complex-app";
      version = "2.0.0";
      app = {
        image = "myapp:latest";
        replicas = 3;
        production = {
          resources = {
            requests = { cpu = "100m"; memory = "128Mi"; };
            limits = { cpu = "500m"; memory = "1Gi"; };
          };
        };
      };
    }
  ];

in
{
  # Run all property tests
  testRequiredLabels = builtins.all testRequiredLabels testConfigs;
  testProductionFeatures = builtins.all testProductionFeatures testConfigs;
}
```

## Performance Optimization

### Nix Evaluation Optimization

```nix
# Use lazy evaluation for large configurations
let
  nix-helm-generator = import ./lib {};

  # Define large configurations as functions
  mkLargeChart = { env, replicas, ... }: let
    baseConfig = {
      name = "large-app";
      version = "1.0.0";
    };

    # Generate many similar resources lazily
    mkResources = count: builtins.genList (i: {
      name = "resource-${toString i}";
      spec = { replicas = 1; };
    }) count;

  in
    nix-helm-generator.mkChart (baseConfig // {
      app = {
        image = "large-app:latest";
        replicas = replicas;
      };

      # Only generate resources when needed
      resources = mkResources replicas;
    });

in
{
  development = mkLargeChart { env = "dev"; replicas = 2; };
  production = mkLargeChart { env = "prod"; replicas = 10; };
}
```

### Build Optimization

```bash
# Use Nix caching effectively
#!/bin/bash

# Build with caching
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

# Use content-addressed store for better caching
nix build --file chart.nix --out-link result-chart

# Use binary cache for faster builds
nix build --file chart.nix --store https://cache.nixos.org
```

### Memory Optimization

```nix
# Avoid keeping large intermediate values in memory
let
  # Process configurations in chunks
  processChunk = chunk: builtins.map (config: {
    name = config.name;
    processed = expensiveOperation config;
  }) chunk;

  # Split large lists into chunks
  chunkSize = 10;
  chunks = splitIntoChunks chunkSize largeConfigList;

  # Process chunks lazily
  processedChunks = builtins.map processChunk chunks;

in
  builtins.concatLists processedChunks
```

### Parallel Processing

```bash
# Build multiple charts in parallel
#!/bin/bash

# Build all environments in parallel
environments=("development" "staging" "production")

for env in "${environments[@]}"; do
  ENV=${env} nix build .#chart &
done

# Wait for all builds to complete
wait

echo "All charts built successfully"
```

This comprehensive best practices guide covers all aspects of using Nix Helm Generator effectively in production environments, from project structure and configuration management to security, monitoring, and performance optimization.