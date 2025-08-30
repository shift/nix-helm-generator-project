# Nix Helm Generator Usage Guide

This guide provides step-by-step instructions for using the Nix Helm Generator module to create production-ready Helm charts from Nix expressions.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Usage](#basic-usage)
- [Production Features](#production-features)
- [Multi-Environment Setup](#multi-environment-setup)
- [Integration with Nix Flakes](#integration-with-nix-flakes)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Set Up Your Project

Create a new directory for your Helm chart project:

```bash
mkdir my-helm-charts
cd my-helm-charts
```

### 2. Add the Nix Helm Generator

You can use the module directly or integrate it via Nix flakes.

**Option A: Direct Import**
```bash
# Clone or download the nix-helm-generator
git clone https://github.com/your-org/nix-helm-generator.git
```

**Option B: Flake Integration**
Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-helm-generator.url = "github:your-org/nix-helm-generator";
  };

  outputs = { self, nixpkgs, nix-helm-generator }: {
    # Your outputs here
  };
}
```

### 3. Create Your First Chart

Create a file `chart.nix`:

```nix
let
  nix-helm-generator = import ./nix-helm-generator/lib {};
in
nix-helm-generator.mkChart {
  name = "hello-world";
  version = "1.0.0";
  description = "A simple hello world application";

  app = {
    image = "nginx:alpine";
    ports = [80];
    env = {
      APP_NAME = "Hello World";
    };
  };
}
```

### 4. Generate the Chart

```bash
# Generate YAML output
nix eval --file chart.nix --json | jq -r '.yamlOutput' > chart.yaml

# Or build as a Nix package
nix build -f chart.nix
```

## Basic Usage

### Simple Web Application

```nix
# simple-app.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "web-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    replicas = 2;
    ports = [80 443];
    env = {
      APP_ENV = "production";
      DOMAIN = "example.com";
    };
  };
}
```

### Application with ConfigMap

```nix
# app-with-config.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "app-with-config";
  version = "1.0.0";

  app = {
    image = "myapp:latest";
    ports = [8080];

    # Configuration data
    configData = {
      "app-config.yaml" = ''
        database:
          host: postgres.example.com
          port: 5432
        redis:
          host: redis.example.com
          port: 6379
      '';
    };

    env = {
      CONFIG_FILE = "/etc/config/app-config.yaml";
    };
  };
}
```

### Application with Ingress

```nix
# app-with-ingress.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "web-service";
  version = "1.0.0";

  app = {
    image = "mywebapp:latest";
    ports = [8080];

    ingress = {
      enabled = true;
      hosts = ["api.example.com" "app.example.com"];
      tls = [
        {
          hosts = ["api.example.com"];
          secretName = "api-tls";
        }
        {
          hosts = ["app.example.com"];
          secretName = "app-tls";
        }
      ];
      annotations = {
        "kubernetes.io/ingress.class" = "nginx";
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
      };
    };
  };
}
```

## Production Features

### Resource Limits and Requests

```nix
# production-app.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "production-app";
  version = "1.0.0";

  app = {
    image = "myapp:v1.0.0";
    replicas = 5;
    ports = [8080];

    production = {
      # Resource management
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

      # Pod Disruption Budget
      pdb = {
        enabled = true;
        minAvailable = 3;  # or "50%" for percentage
      };
    };
  };
}
```

### Health Checks

```nix
# app-with-health-checks.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "healthy-app";
  version = "1.0.0";

  app = {
    image = "myapp:latest";
    ports = [8080];

    production = {
      healthChecks = {
        readinessProbe = {
          httpGet = {
            path = "/ready";
            port = 8080;
          };
          initialDelaySeconds = 10;
          periodSeconds = 10;
          timeoutSeconds = 5;
          failureThreshold = 3;
        };

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
      };
    };
  };
}
```

### Security Context

```nix
# secure-app.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "secure-app";
  version = "1.0.0";

  app = {
    image = "myapp:latest";
    ports = [8080];

    production = {
      securityContext = {
        pod = {
          runAsNonRoot = true;
          runAsUser = 101;
          runAsGroup = 101;
          fsGroup = 101;
        };

        container = {
          allowPrivilegeEscalation = false;
          readOnlyRootFilesystem = true;
          capabilities = {
            drop = ["ALL"];
            add = ["NET_BIND_SERVICE"];
          };
        };
      };
    };
  };
}
```

### Network Policies

```nix
# app-with-network-policy.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "networked-app";
  version = "1.0.0";

  app = {
    image = "myapp:latest";
    ports = [8080];

    production = {
      networkPolicy = {
        enabled = true;

        # Allow traffic from specific pods
        ingress = [
          {
            from = [
              {
                podSelector = {
                  matchLabels = {
                    app = "web-frontend";
                  };
                };
              }
              {
                namespaceSelector = {
                  matchLabels = {
                    name = "ingress-nginx";
                  };
                };
              }
            ];
            ports = [
              {
                port = 8080;
                protocol = "TCP";
              }
            ];
          }
        ];

        # Restrict egress traffic
        egress = [
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
              {
                port = 5432;
                protocol = "TCP";
              }
            ];
          }
          # Allow DNS
          {
            to = [];
            ports = [
              {
                port = 53;
                protocol = "UDP";
              }
            ];
          }
        ];
      };
    };
  };
}
```

## Multi-Environment Setup

### Environment-Specific Configurations

```nix
# multi-env-app.nix
let
  nix-helm-generator = import ./lib {};

  # Base configuration
  baseConfig = {
    name = "multi-env-app";
    version = "1.0.0";

    app = {
      image = "myapp:latest";
      ports = [8080];
    };
  };

  # Environment overrides
  environments = {
    development = {
      app.replicas = 1;
      app.env.DEBUG = "true";
    };

    staging = {
      app.replicas = 2;
      app.env.APP_ENV = "staging";
      namespace = "staging";
    };

    production = {
      app.replicas = 5;
      app.env.APP_ENV = "production";
      namespace = "production";

      app.production = {
        pdb = {
          enabled = true;
          minAvailable = 3;
        };

        resources = {
          requests = { cpu = "200m"; memory = "256Mi"; };
          limits = { cpu = "1000m"; memory = "1Gi"; };
        };
      };
    };
  };

  # Function to merge configurations
  mkEnvChart = env: overrides:
    let
      mergedConfig = nix-helm-generator.lib.recursiveUpdate baseConfig overrides;
    in
    nix-helm-generator.mkChart mergedConfig;

in
{
  development = mkEnvChart "development" environments.development;
  staging = mkEnvChart "staging" environments.staging;
  production = mkEnvChart "production" environments.production;
}
```

### Using Environment Variables

```nix
# env-based-app.nix
let
  nix-helm-generator = import ./lib {};

  # Get environment from command line or default
  env = builtins.getEnv "ENV" or "development";

  config = {
    name = "env-app";
    version = "1.0.0";

    app = {
      image = "myapp:latest";
      ports = [8080];
    };
  } // (if env == "production" then {
    app.replicas = 5;
    app.production = {
      resources = {
        requests = { cpu = "200m"; memory = "256Mi"; };
        limits = { cpu = "1000m"; memory = "1Gi"; };
      };
    };
  } else {
    app.replicas = 1;
  });

in
nix-helm-generator.mkChart config
```

## Integration with Nix Flakes

### Basic Flake Integration

```nix
# flake.nix
{
  description = "My Application Charts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-helm-generator = {
      url = "github:your-org/nix-helm-generator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-helm-generator }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nix-helm-generator.lib;
    in
    {
      packages.${system} = {
        my-app-chart = lib.mkChart {
          name = "my-app";
          version = "1.0.0";
          app = {
            image = "myapp:latest";
            ports = [8080];
          };
        };
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          nix-helm-generator.packages.${system}.default
        ];
      };
    };
}
```

### Advanced Flake with Multiple Charts

```nix
# flake.nix
{
  description = "Multi-Application Chart System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-helm-generator.url = "github:your-org/nix-helm-generator";
  };

  outputs = { self, nixpkgs, nix-helm-generator }:
    let
      system = "x86_64-linux";
      lib = nix-helm-generator.lib;

      # Chart definitions
      charts = {
        frontend = {
          name = "frontend";
          version = "1.0.0";
          app = {
            image = "frontend:latest";
            ports = [80];
          };
        };

        backend = {
          name = "backend";
          version = "1.0.0";
          app = {
            image = "backend:latest";
            ports = [8080];
            production = {
              resources = {
                requests = { cpu = "100m"; memory = "128Mi"; };
                limits = { cpu = "500m"; memory = "512Mi"; };
              };
            };
          };
        };
      };

    in
    {
      packages.${system} = builtins.mapAttrs
        (name: config: lib.mkChart config)
        charts;

      # Combined chart output
      packages.${system}.all-charts = pkgs.writeText "all-charts.yaml"
        (lib.concatStringsSep "\n---\n"
          (builtins.map (chart: chart.yamlOutput)
            (builtins.attrValues self.packages.${system})));
    };
}
```

## Advanced Configuration

### Custom Labels and Annotations

```nix
# advanced-app.nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "advanced-app";
  version = "1.0.0";
  description = "Advanced application with custom metadata";

  # Custom labels applied to all resources
  labels = {
    app = "advanced-app";
    team = "platform";
    environment = "production";
    managed-by = "nix-helm-generator";
  };

  # Chart-level annotations
  annotations = {
    "example.com/created-by" = "nix-helm-generator";
    "example.com/last-updated" = "2024-01-01";
  };

  app = {
    image = "myapp:latest";
    ports = [8080];

    # App-specific labels (merged with chart labels)
    labels = {
      component = "web";
      version = "v1.0.0";
    };
  };
}
```

### Multiple Containers

```nix
# multi-container-app.nix
let
  nix-helm-generator = import ./lib {};
in
# Note: Current version supports single container per deployment
# For multi-container support, use custom resource definitions
nix-helm-generator.mkChart {
  name = "multi-container-app";
  version = "1.0.0";

  app = {
    image = "myapp:latest";
    ports = [8080];

    # For now, use sidecar pattern or custom resources
    # Multi-container support planned for future versions
  };
}
```

### Custom Resource Definitions

```nix
# custom-resources.nix
let
  nix-helm-generator = import ./lib {};
in
let
  baseChart = nix-helm-generator.mkChart {
    name = "custom-app";
    version = "1.0.0";

    app = {
      image = "myapp:latest";
      ports = [8080];
    };
  };

  # Add custom resources
  customResources = {
    # Custom ConfigMap
    customConfig = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "custom-config";
        namespace = "default";
      };
      data = {
        "custom.yaml" = "key: value";
      };
    };

    # Custom Secret
    appSecret = {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "app-secret";
        namespace = "default";
      };
      type = "Opaque";
      data = {
        password = "cGFzc3dvcmQ=";  # base64 encoded
      };
    };
  };

in
baseChart // {
  yamlOutput = baseChart.yamlOutput + "\n---\n" +
    (builtins.concatStringsSep "\n---\n"
      (builtins.map builtins.toJSON
        (builtins.attrValues customResources)));
}
```

## Troubleshooting

### Common Issues

#### 1. Validation Errors

**Error:** "Chart validation failed: Missing required fields: name"

**Solution:** Ensure all required fields are provided:
```nix
{
  name = "my-app";      # Required
  version = "1.0.0";    # Required
  # ... other config
}
```

#### 2. Image Not Specified

**Error:** "Invalid app configuration: image is required"

**Solution:** Always specify the container image:
```nix
app = {
  image = "nginx:alpine";  # Required
  # ... other app config
};
```

#### 3. Invalid Version Format

**Error:** "Invalid version format: must be semantic version (x.y.z)"

**Solution:** Use semantic versioning:
```nix
version = "1.0.0";    # ✓ Valid
version = "1.0";      # ✗ Invalid
version = "latest";   # ✗ Invalid
```

#### 4. Port Configuration Issues

**Problem:** Service not exposing correct ports

**Solution:** Ensure ports are specified as a list:
```nix
app = {
  ports = [80 443];  # ✓ List of integers
  ports = [80];      # ✓ Single port as list
  ports = 80;        # ✗ Not a list
};
```

### Debugging Tips

#### 1. Inspect Generated Resources

```bash
# Evaluate and inspect the chart structure
nix eval --file chart.nix --json | jq '.'

# Generate YAML and examine it
nix eval --file chart.nix --json | jq -r '.yamlOutput' | less
```

#### 2. Test Individual Components

```bash
# Test validation
nix eval --expr '(import ./lib {}).validation.validateChartConfig { name = "test"; version = "1.0.0"; }'

# Test resource generation
nix eval --expr '(import ./lib {}).resources.mkDeployment { name = "test"; } { image = "nginx"; }'
```

#### 3. Use Debug Mode

```bash
# Enable debug output
NIX_DEBUG=1 nix eval --file chart.nix
```

### Performance Considerations

#### 1. Large Charts

For very large charts with many resources, consider:

```nix
# Split large charts into smaller ones
# Use separate files for different components
let
  webChart = import ./web-chart.nix;
  apiChart = import ./api-chart.nix;
  dbChart = import ./db-chart.nix;
in
{
  web = webChart;
  api = apiChart;
  database = dbChart;
}
```

#### 2. Caching

```bash
# Use Nix caching for faster rebuilds
nix build --file chart.nix --out-link result-chart
```

### Getting Help

1. **Check the Documentation:** Review this guide and the API reference
2. **Validate Your Config:** Use the validation functions
3. **Test Incrementally:** Build up your configuration step by step
4. **Community Support:** Check GitHub issues and discussions

### Migration from Helm Templates

#### Key Differences

| Helm Templates | Nix Helm Generator |
|---------------|-------------------|
| `{{ .Values.image }}` | `config.app.image` |
| `{{ .Release.Name }}` | `config.name` |
| `{{ .Chart.Version }}` | `config.version` |
| Template logic | Nix functions |
| values.yaml | Nix attribute sets |

#### Migration Example

**Helm Template:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicas }}
  template:
    spec:
      containers:
      - name: app
        image: {{ .Values.image }}
        ports:
        - containerPort: {{ .Values.port }}
```

**Nix Helm Generator:**
```nix
{
  name = "my-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    replicas = 3;
    ports = [80];
  };
}
```

This eliminates the need for template syntax and provides compile-time validation and type safety.