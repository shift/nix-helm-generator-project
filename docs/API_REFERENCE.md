# Nix Helm Generator API Reference

This document provides a complete reference for the Nix Helm Generator module API, designed for junior DevOps engineers and developers who want to generate production-ready Helm charts using Nix.

## Table of Contents

- [Core Functions](#core-functions)
- [Chart Module](#chart-module)
- [Resources Module](#resources-module)
- [Production Module](#production-module)
- [Validation Module](#validation-module)
- [Configuration Schema](#configuration-schema)
- [Examples](#examples)

## Core Functions

### `mkChart`

The main entry point for generating Helm charts from Nix expressions.

**Signature:**
```nix
mkChart :: AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration object

**Returns:**
An attribute set containing:
- `chartMeta`: Chart metadata
- `k8sResources`: Generated Kubernetes resources
- `productionResources`: Resources with production features applied
- `yamlOutput`: Complete YAML output as string
- `toString`: Convenience function returning YAML string
- `toFile`: Function to write YAML to a file

**Example:**
```nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "my-app";
  version = "1.0.0";
  app = {
    image = "nginx:alpine";
    ports = [80];
  };
}
```

## Chart Module

Functions for generating Helm chart metadata and YAML output.

### `mkChartMetadata`

Generates Chart.yaml metadata for the Helm chart.

**Signature:**
```nix
mkChartMetadata :: AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration

**Returns:**
Chart metadata attribute set with fields like `apiVersion`, `name`, `version`, etc.

**Configuration Options:**
- `name` (string): Chart name (required)
- `version` (string): Chart version (required)
- `description` (string): Chart description (optional)
- `apiVersion` (string): Helm API version (default: "v2")
- `type` (string): Chart type (default: "application")
- `keywords` (list): List of keywords (optional)
- `home` (string): Home URL (optional)
- `sources` (list): List of source URLs (optional)
- `maintainers` (list): List of maintainer objects (optional)
- `dependencies` (list): List of chart dependencies (optional)
- `annotations` (attrset): Chart annotations (optional)

### `mkYamlOutput`

Combines chart metadata and resources into complete YAML output.

**Signature:**
```nix
mkYamlOutput :: AttrSet -> AttrSet -> String
```

**Parameters:**
- `chartMeta` (AttrSet): Chart metadata
- `resources` (AttrSet): Kubernetes resources

**Returns:**
Complete YAML string containing Chart.yaml, values.yaml, and all manifests.

## Resources Module

Functions for generating Kubernetes resources.

### `mkDeployment`

Creates a Kubernetes Deployment resource.

**Signature:**
```nix
mkDeployment :: AttrSet -> AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application-specific configuration

**Configuration Options:**
- `config.name` (string): Application name
- `config.namespace` (string): Target namespace (default: "default")
- `config.labels` (attrset): Labels for the deployment
- `appConfig.replicas` (int): Number of replicas (default: 1)
- `appConfig.image` (string): Container image
- `appConfig.ports` (list): List of ports to expose
- `appConfig.env` (attrset): Environment variables

### `mkService`

Creates a Kubernetes Service resource.

**Signature:**
```nix
mkService :: AttrSet -> AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application-specific configuration

**Configuration Options:**
- `appConfig.ports` (list): List of ports
- `appConfig.serviceType` (string): Service type (default: "ClusterIP")

### `mkConfigMap`

Creates a Kubernetes ConfigMap resource (only if data is provided).

**Signature:**
```nix
mkConfigMap :: AttrSet -> AttrSet -> AttrSet|null
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application-specific configuration

**Configuration Options:**
- `appConfig.configData` (attrset): Configuration data for the ConfigMap

**Returns:** ConfigMap resource or `null` if no data provided.

### `mkIngress`

Creates a Kubernetes Ingress resource (only if enabled).

**Signature:**
```nix
mkIngress :: AttrSet -> AttrSet -> AttrSet|null
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application-specific configuration

**Configuration Options:**
- `appConfig.ingress.enabled` (bool): Whether to create ingress
- `appConfig.ingress.hosts` (list): List of hostnames
- `appConfig.ingress.tls` (list): TLS configuration
- `appConfig.ingress.annotations` (attrset): Ingress annotations
- `appConfig.ingress.className` (string): Ingress class name

**Returns:** Ingress resource or `null` if disabled.

### `mkResources`

Main function that generates all basic Kubernetes resources.

**Signature:**
```nix
mkResources :: AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Complete chart configuration

**Returns:** Attribute set containing all generated resources.

## Production Module

Functions for adding production-ready features to deployments.

### `mkPDB`

Creates a Pod Disruption Budget resource.

**Signature:**
```nix
mkPDB :: AttrSet -> AttrSet -> AttrSet|null
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application configuration

**Configuration Options:**
- `appConfig.production.pdb.enabled` (bool): Enable PDB
- `appConfig.production.pdb.minAvailable` (string): Minimum available pods
- `appConfig.production.pdb.maxUnavailable` (string): Maximum unavailable pods

### `applyResources`

Applies resource requests and limits to containers.

**Signature:**
```nix
applyResources :: AttrSet -> List -> List
```

**Parameters:**
- `appConfig` (AttrSet): Application configuration
- `containers` (List): List of container specifications

**Configuration Options:**
- `appConfig.production.resources.requests` (attrset): Resource requests
- `appConfig.production.resources.limits` (attrset): Resource limits

### `applyHealthChecks`

Adds readiness and liveness probes to containers.

**Signature:**
```nix
applyHealthChecks :: AttrSet -> List -> List
```

**Parameters:**
- `appConfig` (AttrSet): Application configuration
- `containers` (List): List of container specifications

**Configuration Options:**
- `appConfig.production.healthChecks.readinessProbe` (attrset): Readiness probe config
- `appConfig.production.healthChecks.livenessProbe` (attrset): Liveness probe config

### `applySecurityContext`

Applies security context to pod and containers.

**Signature:**
```nix
applySecurityContext :: AttrSet -> AttrSet -> AttrSet
```

**Parameters:**
- `appConfig` (AttrSet): Application configuration
- `spec` (AttrSet): Pod specification

**Configuration Options:**
- `appConfig.production.securityContext.pod` (attrset): Pod security context
- `appConfig.production.securityContext.container` (attrset): Container security context

### `mkNetworkPolicy`

Creates a NetworkPolicy resource.

**Signature:**
```nix
mkNetworkPolicy :: AttrSet -> AttrSet -> AttrSet|null
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `appConfig` (AttrSet): Application configuration

**Configuration Options:**
- `appConfig.production.networkPolicy.enabled` (bool): Enable network policy
- `appConfig.production.networkPolicy.ingress` (list): Ingress rules
- `appConfig.production.networkPolicy.egress` (list): Egress rules

### `mkProductionResources`

Main function that applies all production features to resources.

**Signature:**
```nix
mkProductionResources :: AttrSet -> AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration
- `resources` (AttrSet): Base resources to enhance

**Returns:** Resources with production features applied.

## Validation Module

Functions for validating chart configurations.

### `validateChartConfig`

Validates the complete chart configuration.

**Signature:**
```nix
validateChartConfig :: AttrSet -> AttrSet
```

**Parameters:**
- `config` (AttrSet): Chart configuration to validate

**Returns:** Validated configuration or throws error with details.

**Validation Rules:**
- `name` field is required and must be ≤ 63 characters
- `version` field is required and must be semantic version (x.y.z)
- If `app` is present, `app.image` must be provided

## Configuration Schema

### Complete Configuration Structure

```nix
{
  # Required fields
  name = "my-app";
  version = "1.0.0";

  # Optional metadata
  description = "My application";
  apiVersion = "v2";
  type = "application";
  keywords = ["web" "api"];
  home = "https://example.com";
  sources = ["https://github.com/example/my-app"];
  maintainers = [
    {
      name = "John Doe";
      email = "john@example.com";
    }
  ];
  dependencies = [];
  annotations = {};

  # Application configuration
  app = {
    # Basic settings
    image = "nginx:alpine";
    replicas = 3;
    ports = [80 443];
    env = {
      APP_ENV = "production";
      DEBUG = "false";
    };

    # Service configuration
    serviceType = "ClusterIP";

    # ConfigMap data
    configData = {
      "config.yaml" = "...";
    };

    # Ingress configuration
    ingress = {
      enabled = true;
      hosts = ["my-app.example.com"];
      tls = [
        {
          hosts = ["my-app.example.com"];
          secretName = "my-app-tls";
        }
      ];
      annotations = {
        "kubernetes.io/ingress.class" = "nginx";
      };
      className = "nginx";
    };

    # Production features
    production = {
      # Pod Disruption Budget
      pdb = {
        enabled = true;
        minAvailable = "50%";
        maxUnavailable = "25%";
      };

      # Resource limits and requests
      resources = {
        requests = {
          cpu = "100m";
          memory = "128Mi";
        };
        limits = {
          cpu = "500m";
          memory = "512Mi";
        };
      };

      # Health checks
      healthChecks = {
        readinessProbe = {
          httpGet = {
            path = "/ready";
            port = 80;
          };
          initialDelaySeconds = 5;
          periodSeconds = 10;
        };
        livenessProbe = {
          httpGet = {
            path = "/health";
            port = 80;
          };
          initialDelaySeconds = 30;
          periodSeconds = 30;
        };
      };

      # Security context
      securityContext = {
        pod = {
          runAsNonRoot = true;
          runAsUser = 101;
          fsGroup = 101;
        };
        container = {
          allowPrivilegeEscalation = false;
          readOnlyRootFilesystem = true;
          capabilities = {
            drop = ["ALL"];
          };
        };
      };

      # Network policy
      networkPolicy = {
        enabled = true;
        ingress = [
          {
            from = [
              {
                podSelector = {
                  matchLabels = {
                    app = "my-app";
                  };
                };
              }
            ];
            ports = [
              {
                port = 80;
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
                    app = "my-app";
                  };
                };
              }
            ];
          }
        ];
      };
    };
  };

  # Chart-level labels
  labels = {
    app = "my-app";
    version = "v1.0.0";
  };

  # Namespace override
  namespace = "production";
}
```

## Examples

### Basic Application

```nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "simple-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    ports = [80];
  };
}
```

### Production Application

```nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "prod-app";
  version = "2.1.0";

  app = {
    image = "myapp:v2.1.0";
    replicas = 5;
    ports = [8080];

    production = {
      pdb = {
        enabled = true;
        minAvailable = 3;
      };

      resources = {
        requests = { cpu = "200m"; memory = "256Mi"; };
        limits = { cpu = "1000m"; memory = "1Gi"; };
      };

      healthChecks = {
        readinessProbe = {
          httpGet = { path = "/ready"; port = 8080; };
          initialDelaySeconds = 10;
        };
      };
    };
  };
}
```

### Application with Ingress

```nix
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "web-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    ports = [80];

    ingress = {
      enabled = true;
      hosts = ["my-app.example.com"];
      tls = [
        {
          hosts = ["my-app.example.com"];
          secretName = "my-app-tls";
        }
      ];
    };
  };
}
```