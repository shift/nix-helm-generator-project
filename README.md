# Nix Helm Generator

A Nix-based Helm chart generator that creates production-ready Kubernetes manifests from declarative Nix expressions. Generate static YAML without Helm templating complexity while maintaining full GitOps compatibility.

## 🚀 Features

- **📝 Declarative Configuration**: Define your applications using Nix expressions
- **🏭 Production Ready**: Built-in support for resource limits, health checks, and pod disruption budgets
- **🔧 Multi-Chart Support**: Generate multiple related charts with dependency management
- **⚡ Fast Generation**: Static manifest generation with Nix's caching and reproducibility
- **🛡️ Type Safety**: Full input validation and type checking
- **📊 CI/CD Integration**: Built-in GitHub Actions workflows and validation scripts
- **🎯 GitOps Compatible**: Generate versioned charts for ArgoCD, Flux, and other GitOps tools

## 🏃‍♂️ Quick Start

### Prerequisites

- Nix with flakes support (`nix --version` >= 2.4)
- Optional: kubectl, helm (for validation)

### Installation

```bash
# Clone the repository
git clone https://github.com/shift/nix-helm-generator-project.git
cd nix-helm-generator-project

# Enter development environment
nix develop

# Build and test
nix build .#examples
nix flake check
```

### Basic Usage

```bash
# Generate a simple nginx chart
nix run .#my-app

# Generate multiple charts
nix run .#multi-app

# Build all examples
nix build .#examples
```

## 📖 Examples

### Simple Application

```nix
# examples/simple-app.nix
{
  name = "my-web-app";
  version = "1.0.0";
  app = {
    image = "nginx:1.25.0";
    ports = [80];
    replicas = 3;
  };
}
```

### Production Application

```nix
# examples/production-app.nix
{
  name = "production-api";
  version = "2.1.0";
  app = {
    image = "myapi:v2.1.0";
    ports = [8080];
    replicas = 5;
    
    production = {
      resources = {
        requests = { cpu = "200m"; memory = "256Mi"; };
        limits = { cpu = "1000m"; memory = "1Gi"; };
      };
      
      healthChecks = {
        readinessProbe = {
          httpGet = { path = "/health"; port = 8080; };
          initialDelaySeconds = 10;
        };
      };
      
      pdb = {
        enabled = true;
        minAvailable = 3;
      };
    };
  };
}
```

### Multi-Chart Application

```nix
# examples/microservices.nix
{
  name = "microservices-app";
  version = "1.0.0";
  charts = {
    frontend = {
      app = { image = "frontend:latest"; ports = [3000]; };
    };
    backend = {
      app = { image = "backend:latest"; ports = [8080]; };
    };
    database = {
      app = { image = "postgres:14"; ports = [5432]; };
    };
  };
}
```

## 🏗️ Architecture

```
nix-helm-generator/
├── flake.nix              # Nix flake with packages and apps
├── lib/                   # Core generator library
│   ├── default.nix       # Main entry point
│   ├── chart.nix         # Single chart generation
│   ├── multi-chart.nix   # Multi-chart support
│   ├── resources.nix     # Kubernetes resource templates
│   ├── production.nix    # Production features
│   └── validation.nix    # Input validation
├── examples/             # Example configurations
├── tests/               # Test suite
├── cicd/               # CI/CD scripts and validation
└── docs/              # Documentation
```

## 🛠️ Development

### Development Environment

```bash
# Enter Nix development shell
nix develop

# Available tools:
# - nix (for building)
# - kubectl (for validation)
# - helm (for compatibility)
# - jq, yq (for JSON/YAML processing)
```

### Testing

```bash
# Run all validation tests
./cicd/test/validate-charts.sh

# Run integration tests
./cicd/test/integration-test.sh

# Check flake
nix flake check
```

### Adding New Features

1. Update the appropriate module in `lib/`
2. Add examples in `examples/`
3. Add tests in `tests/`
4. Update documentation

## 📊 CI/CD

The project includes comprehensive CI/CD with GitHub Actions:

- **Validation**: Flake checks, chart generation, manifest validation
- **Testing**: Integration tests and performance benchmarks
- **Deployment**: Automated chart generation and publishing

See `.github/workflows/` for the complete pipeline.

## 🎯 Use Cases

- **Microservices Deployment**: Generate consistent charts for multiple services
- **GitOps Workflows**: Create versioned manifests for ArgoCD/Flux
- **Multi-Environment**: Generate environment-specific configurations
- **CI/CD Integration**: Automate chart generation in build pipelines
- **Kubernetes Migration**: Convert existing deployments to declarative Nix

## 📚 Documentation

- [API Reference](./docs/API_REFERENCE.md) - Complete function documentation
- [Usage Guide](./docs/USAGE_GUIDE.md) - Detailed usage examples
- [Best Practices](./docs/BEST_PRACTICES.md) - Production recommendations
- [CI/CD Integration](./docs/CICD_INTEGRATION.md) - Pipeline setup guide
- [Troubleshooting](./docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Quick Contribution Steps

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run validation: `nix flake check`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🔗 Related Projects

- [NixOS](https://nixos.org/) - The Nix package manager and OS
- [Helm](https://helm.sh/) - Kubernetes package manager
- [ArgoCD](https://argo-cd.readthedocs.io/) - GitOps continuous delivery

---

**Made with ❤️ using Nix and Kubernetes**