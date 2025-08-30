# Nix Helm Generator Examples

This directory contains comprehensive examples of commonly used Helm charts reimplemented using the Nix Helm Generator module. Each example demonstrates production-ready configurations with proper security, monitoring, and scalability features.

## Available Examples

### Core Applications

1. **[nginx.nix](nginx.nix)** - Web server with ingress, TLS, and production features
2. **[redis.nix](redis.nix)** - In-memory database with persistence and security
3. **[postgres.nix](postgres.nix)** - PostgreSQL database with advanced configuration
4. **[prometheus.nix](prometheus.nix)** - Monitoring system with service discovery
5. **[elasticsearch.nix](elasticsearch.nix)** - Search and analytics engine
6. **[cert-manager.nix](cert-manager.nix)** - Certificate management for TLS
7. **[ingress-nginx.nix](ingress-nginx.nix)** - Kubernetes ingress controller

### Version-Specific Variants

Located in the `versions/` directory:

- **[nginx-k8s-1.19.nix](versions/nginx-k8s-1.19.nix)** - Uses `networking.k8s.io/v1beta1` for Ingress
- **[nginx-k8s-1.21.nix](versions/nginx-k8s-1.21.nix)** - Uses `policy/v1` for PodDisruptionBudget
- **[nginx-k8s-1.25.nix](versions/nginx-k8s-1.25.nix)** - Uses latest stable API versions

## Features Demonstrated

### Production Features
- **Resource Management**: CPU/memory requests and limits
- **Health Checks**: Readiness and liveness probes
- **Security Context**: Non-root execution, read-only filesystems
- **Pod Disruption Budgets**: High availability guarantees
- **Network Policies**: Traffic security and isolation

### Kubernetes API Version Compatibility
- Automatic API version detection based on `kubernetesVersion`
- Support for multiple Kubernetes versions
- Backward compatibility with older clusters

### Configuration Management
- Environment variables
- ConfigMaps for application configuration
- Secrets for sensitive data (placeholders included)

## Usage

### Basic Usage

```bash
# Generate a chart from an example
nix eval --json .#nginx > nginx-chart.json

# Or use the Nix REPL
nix repl
:load examples/nginx.nix
nginxConfig
```

### With Custom Configuration

```nix
let
  customNginx = import ./examples/nginx.nix { inherit lib; };
  myChart = customNginx // {
    app = customNginx.app // {
      image = "nginx:1.24.0";
      env.NGINX_PORT = "8080";
    };
  };
in
myChart
```

### API Version Targeting

```nix
let
  nginxForOldCluster = import ./examples/nginx.nix { inherit lib; };
  chart = nginxForOldCluster // {
    kubernetesVersion = "1.19.0";  # Will use v1beta1 APIs
  };
in
chart
```

## Chart Structure

Each example generates a complete Helm chart with:

```
Chart.yaml          # Chart metadata
values.yaml         # Default values (empty for now)
templates/          # Kubernetes manifests
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── ingress.yaml
├── pdb.yaml
└── networkpolicy.yaml
```

## Testing Examples

```bash
# Test chart generation
nix-build -E "(import ./examples/nginx.nix { lib = import <nixpkgs> {}.lib; })"

# Validate generated YAML
kubectl apply --dry-run=client -f result/

# Check API versions
grep "apiVersion" result/*
```

## Production Deployment

### Prerequisites

1. **Kubernetes Cluster**: Version 1.19+ for full feature support
2. **Ingress Controller**: For ingress examples
3. **Cert-Manager**: For TLS certificate examples
4. **Storage Classes**: For persistent volume examples

### Deployment Steps

```bash
# 1. Generate the chart
nix eval --json .#nginx > nginx-chart.json

# 2. Convert to Helm format (if needed)
# The generated output is ready for kubectl

# 3. Deploy to Kubernetes
kubectl apply -f nginx-chart.json

# 4. Verify deployment
kubectl get pods -l app=nginx
kubectl get ingress nginx
```

## Customization Guide

### Adding Custom Environment Variables

```nix
app = {
  # ... existing config
  env = {
    MY_CUSTOM_VAR = "value";
    DATABASE_URL = "postgres://...";
  };
};
```

### Configuring Resource Limits

```nix
production = {
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
};
```

### Setting Up Health Checks

```nix
production = {
  healthChecks = {
    readinessProbe = {
      httpGet = {
        path = "/health";
        port = 8080;
      };
      initialDelaySeconds = 10;
      periodSeconds = 5;
    };
    livenessProbe = {
      tcpSocket = {
        port = 8080;
      };
      initialDelaySeconds = 30;
      periodSeconds = 10;
    };
  };
};
```

### Configuring Ingress

```nix
ingress = {
  enabled = true;
  hosts = ["myapp.example.com"];
  annotations = {
    "kubernetes.io/ingress.class" = "nginx";
    "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
  };
  tls = [
    {
      secretName = "myapp-tls";
      hosts = ["myapp.example.com"];
    }
  ];
};
```

## API Version Compatibility

The module automatically detects the Kubernetes version and uses appropriate API versions:

| Kubernetes Version | Ingress API | PDB API | NetworkPolicy API |
|-------------------|-------------|---------|-------------------|
| < 1.19           | v1beta1     | v1beta1 | v1                |
| 1.19 - 1.20      | v1          | v1beta1 | v1                |
| >= 1.21          | v1          | v1      | v1                |

## Security Considerations

### Default Security Features
- Non-root user execution
- Read-only root filesystem where possible
- No privilege escalation
- Network policies for traffic isolation
- Resource limits to prevent resource exhaustion

### Additional Security Measures
- Use secrets for sensitive data (passwords, tokens)
- Implement proper RBAC
- Regular security updates of base images
- Network segmentation
- Audit logging

## Troubleshooting

### Common Issues

1. **API Version Errors**
   - Check your Kubernetes version
   - Set `kubernetesVersion` in chart config
   - Ensure cluster supports required APIs

2. **Image Pull Errors**
   - Verify image names and tags
   - Check image registry access
   - Use private registry credentials if needed

3. **Resource Quota Issues**
   - Adjust resource requests/limits
   - Check namespace resource quotas
   - Monitor resource usage

4. **Network Policy Conflicts**
   - Review existing network policies
   - Check pod selectors and namespaces
   - Test connectivity after deployment

### Debug Commands

```bash
# Check generated resources
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Test network connectivity
kubectl exec -it <pod-name> -- curl <service-url>

# Check API versions
kubectl api-versions | grep -E "(networking|policy)"
```

## Contributing

When adding new examples:

1. Follow the existing pattern and structure
2. Include comprehensive production features
3. Add appropriate documentation
4. Test across multiple Kubernetes versions
5. Update this README with new examples

## Next Steps

After implementing these examples:

1. **Test thoroughly** across different Kubernetes versions
2. **Add more complex examples** (stateful sets, operators, etc.)
3. **Create CI/CD pipelines** for automated testing
4. **Document advanced patterns** and best practices
5. **Hand off to Testing Agent** for comprehensive validation