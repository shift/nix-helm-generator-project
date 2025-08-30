# Troubleshooting and Best Practices

This guide covers common issues, debugging techniques, and best practices for using the Nix Helm Generator module.

## Table of Contents

- [Common Issues](#common-issues)
- [Debugging Techniques](#debugging-techniques)
- [Performance Optimization](#performance-optimization)
- [Best Practices](#best-practices)
- [Migration Guide](#migration-guide)
- [FAQ](#faq)

## Common Issues

### Configuration Validation Errors

#### Issue: "Missing required fields: name"

**Symptoms:**
```
error: Chart validation failed:
Missing required fields: name
```

**Cause:** The `name` field is not provided in the chart configuration.

**Solution:**
```nix
# ❌ Incorrect
nix-helm-generator.mkChart {
  version = "1.0.0";
  # Missing name field
}

# ✅ Correct
nix-helm-generator.mkChart {
  name = "my-app";      # Required
  version = "1.0.0";    # Required
}
```

#### Issue: "Invalid version format: must be semantic version (x.y.z)"

**Symptoms:**
```
error: Chart validation failed:
Invalid version format: must be semantic version (x.y.z)
```

**Cause:** Version doesn't follow semantic versioning format.

**Solution:**
```nix
# ❌ Incorrect
version = "1.0";
version = "latest";
version = "v1.0.0";

# ✅ Correct
version = "1.0.0";
version = "2.1.3";
version = "0.1.0-alpha";
```

#### Issue: "Invalid app configuration: image is required"

**Symptoms:**
```
error: Chart validation failed:
Invalid app configuration: image is required
```

**Cause:** The `app.image` field is missing when `app` configuration is provided.

**Solution:**
```nix
# ❌ Incorrect
app = {
  ports = [80];
  # Missing image field
}

# ✅ Correct
app = {
  image = "nginx:alpine";  # Required
  ports = [80];
}
```

### Resource Generation Issues

#### Issue: Service not exposing correct ports

**Symptoms:** Service is created but doesn't expose the expected ports.

**Cause:** Ports configuration is incorrect.

**Solution:**
```nix
# ❌ Incorrect - ports as single value
app = {
  ports = 80;
}

# ❌ Incorrect - ports as string
app = {
  ports = ["80"];
}

# ✅ Correct - ports as list of integers
app = {
  ports = [80];
  # Or multiple ports
  ports = [80 443];
}
```

#### Issue: Ingress not working

**Symptoms:** Ingress resource is created but traffic isn't routed correctly.

**Common Causes:**
1. Missing ingress class annotation
2. Incorrect host configuration
3. TLS secret not found

**Solution:**
```nix
app = {
  ports = [80];

  ingress = {
    enabled = true;
    hosts = ["my-app.example.com"];

    # Add ingress class annotation
    annotations = {
      "kubernetes.io/ingress.class" = "nginx";
    };

    # Optional: TLS configuration
    tls = [
      {
        hosts = ["my-app.example.com"];
        secretName = "my-app-tls";
      }
    ];
  };
}
```

#### Issue: ConfigMap not created

**Symptoms:** ConfigMap resource is not generated.

**Cause:** `configData` is empty or not provided.

**Solution:**
```nix
# ❌ Incorrect - empty configData
app = {
  configData = {};
}

# ✅ Correct - provide actual data
app = {
  configData = {
    "config.yaml" = ''
      key: value
      database:
        host: postgres
    '';
  };
}
```

### Production Feature Issues

#### Issue: Resource limits not applied

**Symptoms:** Containers don't have the expected resource limits.

**Cause:** Production configuration is incomplete.

**Solution:**
```nix
app = {
  production = {
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
  };
}
```

#### Issue: Health checks failing

**Symptoms:** Pods are restarting due to failed health checks.

**Common Causes:**
1. Incorrect probe paths
2. Wrong port numbers
3. Insufficient initial delay

**Solution:**
```nix
app = {
  production = {
    healthChecks = {
      readinessProbe = {
        httpGet = {
          path = "/ready";    # Ensure this endpoint exists
          port = 8080;        # Use correct port
        };
        initialDelaySeconds = 10;  # Give app time to start
        periodSeconds = 10;
        timeoutSeconds = 5;
        failureThreshold = 3;
      };
    };
  };
}
```

## Debugging Techniques

### Inspect Chart Structure

```bash
# View the complete chart structure
nix eval --file chart.nix --json | jq '.'

# Pretty print the YAML output
nix eval --file chart.nix --json | jq -r '.yamlOutput' | yq eval -P

# Save YAML for inspection
nix eval --file chart.nix --json | jq -r '.yamlOutput' > debug.yaml
```

### Test Individual Components

```bash
# Test validation
nix eval --expr '
  let lib = import ./lib {};
  in lib.validation.validateChartConfig {
    name = "test-app";
    version = "1.0.0";
    app = { image = "nginx"; };
  }
'

# Test resource generation
nix eval --expr '
  let lib = import ./lib {};
  in lib.resources.mkDeployment
    { name = "test"; namespace = "default"; }
    { image = "nginx"; ports = [80]; }
'

# Test YAML generation
nix eval --expr '
  let lib = import ./lib {};
  in lib.chart.mkYamlOutput
    { name = "test"; version = "1.0.0"; }
    { deployment = { apiVersion = "apps/v1"; kind = "Deployment"; }; }
'
```

### Debug with Logging

```bash
# Enable Nix debug output
NIX_DEBUG=1 nix eval --file chart.nix

# Use trace functions for debugging
let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart (builtins.trace "Config: " {
  name = "debug-app";
  version = "1.0.0";
  app = builtins.trace "App config: " {
    image = "nginx:alpine";
    ports = [80];
  };
})
```

### Validate Generated YAML

```bash
# Generate and validate with kubectl
nix eval --file chart.nix --json | jq -r '.yamlOutput' | kubectl apply --dry-run=client -f -

# Check YAML syntax
nix eval --file chart.nix --json | jq -r '.yamlOutput' | yq eval

# Validate against Kubernetes schema
nix eval --file chart.nix --json | jq -r '.yamlOutput' | kubeval -
```

## Performance Optimization

### Large Chart Optimization

For charts with many resources, consider these optimizations:

```nix
# Split large charts into smaller components
let
  nix-helm-generator = import ./lib {};

  # Define components separately
  webComponent = {
    name = "web";
    app = { image = "web:latest"; ports = [80]; };
  };

  apiComponent = {
    name = "api";
    app = { image = "api:latest"; ports = [8080]; };
  };

  dbComponent = {
    name = "db";
    app = { image = "postgres:latest"; ports = [5432]; };
  };

in
{
  web = nix-helm-generator.mkChart webComponent;
  api = nix-helm-generator.mkChart apiComponent;
  database = nix-helm-generator.mkChart dbComponent;
}
```

### Nix Caching

```bash
# Use result symlinks for faster rebuilds
nix build --file chart.nix --out-link result-chart

# Use Nix store for caching
nix store add-file ./chart.nix
```

### Memory Optimization

```nix
# Avoid large attribute sets in memory
let
  # Use lazy evaluation
  largeConfig = {
    # Define large configurations as functions
    getResources = config: /* resource generation logic */;
  };

  chart = nix-helm-generator.mkChart {
    name = "large-app";
    version = "1.0.0";
    app = largeConfig.getResources baseConfig;
  };
in
chart
```

## Best Practices

### Configuration Organization

#### 1. Use Descriptive Names

```nix
# ✅ Good
{
  name = "user-authentication-service";
  version = "2.1.0";
}

# ❌ Avoid
{
  name = "uas";
  version = "1";
}
```

#### 2. Group Related Configuration

```nix
# ✅ Organized
{
  name = "web-app";
  version = "1.0.0";

  app = {
    # Basic settings
    image = "nginx:alpine";
    replicas = 3;

    # Networking
    ports = [80 443];

    # Production features
    production = {
      resources = { /* ... */ };
      healthChecks = { /* ... */ };
    };
  };
}
```

#### 3. Use Constants for Repeated Values

```nix
let
  # Define constants
  appName = "my-app";
  appVersion = "1.0.0";
  namespace = "production";

  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = appName;
  version = appVersion;
  namespace = namespace;

  app = {
    image = "${appName}:${appVersion}";
    # ...
  };
}
```

### Security Best Practices

#### 1. Use Non-Root Containers

```nix
app = {
  production = {
    securityContext = {
      pod = {
        runAsNonRoot = true;
        runAsUser = 101;
        runAsGroup = 101;
      };
      container = {
        allowPrivilegeEscalation = false;
        readOnlyRootFilesystem = true;
      };
    };
  };
}
```

#### 2. Implement Network Policies

```nix
app = {
  production = {
    networkPolicy = {
      enabled = true;
      ingress = [
        {
          from = [
            {
              podSelector = {
                matchLabels = { app = "web-frontend"; };
              };
            }
          ];
        }
      ];
    };
  };
}
```

#### 3. Use Secrets for Sensitive Data

```nix
# Avoid hardcoding secrets
app = {
  env = {
    # ❌ Don't do this
    DATABASE_PASSWORD = "secret123";

    # ✅ Use Kubernetes secrets
    DATABASE_PASSWORD = {
      valueFrom = {
        secretKeyRef = {
          name = "db-secret";
          key = "password";
        };
      };
    };
  };
}
```

### Resource Management

#### 1. Set Appropriate Resource Limits

```nix
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

#### 2. Configure Pod Disruption Budgets

```nix
app = {
  production = {
    pdb = {
      enabled = true;
      # Ensure at least 50% of pods are available during disruptions
      minAvailable = "50%";
    };
  };
}
```

### Monitoring and Observability

#### 1. Implement Health Checks

```nix
app = {
  production = {
    healthChecks = {
      readinessProbe = {
        httpGet = { path = "/ready"; port = 8080; };
        initialDelaySeconds = 10;
      };
      livenessProbe = {
        httpGet = { path = "/health"; port = 8080; };
        initialDelaySeconds = 30;
      };
    };
  };
}
```

#### 2. Add Appropriate Labels

```nix
{
  labels = {
    app = "my-app";
    version = "v1.0.0";
    team = "platform";
    environment = "production";
  };

  app = {
    labels = {
      component = "web";
      tier = "frontend";
    };
  };
}
```

## Migration Guide

### From Helm Templates

#### Key Differences

| Aspect | Helm Templates | Nix Helm Generator |
|--------|----------------|-------------------|
| Values | `values.yaml` | Nix attribute sets |
| Templating | `{{ .Values.key }}` | Direct attribute access |
| Logic | Template functions | Nix functions |
| Validation | Optional | Built-in |
| Type Safety | None | Nix types |

#### Migration Steps

1. **Convert values.yaml to Nix**
   ```yaml
   # values.yaml
   image: nginx:alpine
   replicas: 3
   ports:
     - 80
     - 443
   ```

   ```nix
   # config.nix
   {
     app = {
       image = "nginx:alpine";
       replicas = 3;
       ports = [80 443];
     };
   }
   ```

2. **Replace template logic with Nix functions**
   ```yaml
   # Helm template
   replicas: {{ .Values.replicas }}
   image: {{ .Values.image }}
   {{- if .Values.ingress.enabled }}
   # ingress config
   {{- end }}
   ```

   ```nix
   # Nix
   {
     app = {
       replicas = config.replicas;
       image = config.image;
     } // (if config.ingress.enabled then {
       ingress = config.ingress;
     } else {});
   }
   ```

3. **Update CI/CD pipelines**
   ```bash
   # Old Helm workflow
   helm template . > manifests.yaml
   kubectl apply -f manifests.yaml

   # New Nix workflow
   nix build .#chart
   kubectl apply -f result/
   ```

### From Kustomize

#### Key Differences

| Aspect | Kustomize | Nix Helm Generator |
|--------|-----------|-------------------|
| Base | YAML overlays | Nix expressions |
| Patching | Strategic merge | Attribute merging |
| Variables | ConfigMapGenerator | Nix variables |
| Validation | None | Built-in |

#### Migration Steps

1. **Convert base resources**
   ```yaml
   # kustomize base/deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   spec:
     replicas: 1
     template:
       spec:
         containers:
         - image: nginx
   ```

   ```nix
   # base.nix
   {
     app = {
       image = "nginx";
       replicas = 1;
     };
   }
   ```

2. **Convert overlays to Nix attribute merging**
   ```yaml
   # kustomize overlays/production/deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   spec:
     replicas: 5
   ```

   ```nix
   # production.nix
   let
     base = import ./base.nix;
   in
   base // {
     app.replicas = 5;
     app.production = {
       resources = { /* ... */ };
     };
   }
   ```

## FAQ

### General Questions

**Q: Why use Nix Helm Generator instead of Helm?**

A: Nix Helm Generator provides:
- Compile-time validation
- Type safety
- No runtime templating errors
- Better reproducibility
- Integration with Nix ecosystem

**Q: Can I use existing Helm charts?**

A: You can convert Helm charts to Nix expressions, but the module generates its own YAML manifests. For existing Helm charts, consider using `helm template` with Nix Helm Generator for validation.

**Q: How does it handle secrets?**

A: The module generates Kubernetes Secret resources like any other resource. For sensitive data, use Kubernetes secrets and reference them in your Nix configuration.

### Technical Questions

**Q: Can I customize the generated YAML?**

A: Yes, you can:
1. Use the individual module functions
2. Post-process the generated YAML
3. Add custom resources to the output

**Q: How do I handle multi-container pods?**

A: Currently, the module supports single-container deployments. For multi-container pods, you can:
1. Use custom resource definitions
2. Create sidecar containers manually
3. Extend the module for multi-container support

**Q: What's the performance impact?**

A: Nix evaluation is fast, and the module is designed for performance. For very large charts, consider splitting them into smaller components.

### Integration Questions

**Q: How do I integrate with CI/CD?**

A: You can:
1. Use `nix build` to generate charts
2. Use `nix eval` to get JSON output
3. Integrate with GitOps tools like ArgoCD or Flux

**Q: Can I use it with different Kubernetes distributions?**

A: Yes, the generated YAML is standard Kubernetes manifests that work with any Kubernetes distribution.

**Q: How do I handle different environments?**

A: Use Nix functions to create environment-specific configurations:
```nix
mkEnvChart = env: config:
  nix-helm-generator.mkChart (config // {
    namespace = env;
    app.replicas = if env == "production" then 5 else 1;
  });
```

### Support Questions

**Q: Where can I get help?**

A: 
1. Check this documentation
2. Review the examples in the repository
3. Open issues on GitHub
4. Join the Nix community

**Q: How do I contribute?**

A:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

**Q: What's the roadmap?**

A: Future plans include:
- Multi-container pod support
- CRD generation
- Integration with Helm repositories
- More production features