# Nix Helm Generator

A Nix module that generates production-ready Helm charts from Nix expressions, producing static YAML manifests without Helm templating for more predictable and auditable deployments.

## Overview

This project provides a simple yet powerful way to create Kubernetes deployments using Nix's declarative approach. By generating static YAML manifests, we eliminate the complexity and unpredictability of Helm templating while maintaining all the benefits of Infrastructure as Code.

### Key Features

- **YAML Generation**: Generate complete Helm chart YAML manifests from Nix expressions
- **Production Ready**: Support for pod disruption budgets, resource limits, health checks, and other production features
- **Developer Friendly**: Simple API that junior DevOps engineers can use without deep Nix or Kubernetes expertise
- **Static Manifests**: No Helm templating - all values resolved at build time for predictability
- **Multi-environment Support**: Easy configuration for dev/staging/prod environments

## Quick Start

```bash
# Clone or set up the project
git clone <repository-url>
cd nix-helm-generator

# Use Nix flake for development
nix develop

# Generate a simple chart
nix build .#simple-app
```

## Documentation

- **[Project Kickoff Document](./nix-helm-generator-kickoff.md)**: Complete project overview, architecture, and implementation roadmap
- **[AI Agent Workflow](./ai-agent-workflow/README.md)**: Development workflow and task management system
- **[API Reference](./docs/API_REFERENCE.md)**: Complete API documentation for all functions
- **[Usage Guide](./docs/USAGE_GUIDE.md)**: Step-by-step usage instructions and examples
- **[Best Practices](./docs/BEST_PRACTICES.md)**: Recommended practices for production use
- **[Troubleshooting](./docs/TROUBLESHOOTING.md)**: Common issues and debugging techniques

## Project Structure

```
nix-helm-generator/
├── flake.nix                 # Nix flake configuration
├── lib/                     # Core generation logic
│   ├── chart.nix           # Chart metadata handling
│   ├── resources.nix       # Kubernetes resource generators
│   ├── production.nix      # Production features (PDBs, limits, etc.)
│   └── validation.nix      # Input validation and type checking
├── examples/               # Usage examples
│   ├── simple-app.nix      # Basic application example
│   ├── complex-app.nix     # Full production example
│   └── multi-env.nix       # Multi-environment setup
├── tests/                  # Test suites
├── docs/                   # Documentation
└── nix-helm-generator-kickoff.md  # Project kickoff document
```

## Quick Examples

### Simple Application

```nix
let
  nix-helm-generator = import ./lib;
in
nix-helm-generator.mkChart {
  name = "simple-web-app";
  version = "1.0.0";

  app = {
    image = "nginx:alpine";
    ports = [80];
    env = {
      APP_ENV = "production";
    };
  };
}
```

### Production Application

```nix
let
  nix-helm-generator = import ./lib;
in
nix-helm-generator.mkChart {
  name = "production-app";
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

For comprehensive examples and detailed usage instructions, see the **[Usage Guide](./docs/USAGE_GUIDE.md)**.

## Development

This project uses the AI Agent Workflow Management System for development. See [ai-agent-workflow/README.md](./ai-agent-workflow/README.md) for details on the development process.

### Prerequisites

- Nix 2.8+ with flakes support
- Kubernetes 1.19+ (for testing generated manifests)
- Helm 3.x (for chart packaging)

### Getting Started

1. Enter the development environment:
   ```bash
   nix develop
   ```

2. Check active tasks:
   ```bash
   cat ai-agent-workflow/todo.md
   ```

3. Start working on tasks following the workflow documented in [ai-agent-workflow/WORKFLOW.md](./ai-agent-workflow/WORKFLOW.md)

## Contributing

See [ai-agent-workflow/README.md](./ai-agent-workflow/README.md) for information about the development workflow and contribution guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*For detailed project information, see the [Project Kickoff Document](./nix-helm-generator-kickoff.md)*