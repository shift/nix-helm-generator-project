# Contributing to Nix Helm Generator

Thank you for your interest in contributing to Nix Helm Generator! This document provides guidelines and instructions for contributing to the project.

## 🎯 Ways to Contribute

- **🐛 Bug Reports**: Report issues and bugs
- **💡 Feature Requests**: Suggest new features and improvements
- **📝 Documentation**: Improve docs, examples, and guides
- **💻 Code**: Submit bug fixes and new features
- **🧪 Testing**: Add tests and improve test coverage
- **📊 Performance**: Optimize chart generation and validation

## 🚀 Getting Started

### Prerequisites

- **Nix**: Version 2.4+ with flakes support enabled
- **Git**: For version control
- **GitHub Account**: For submitting pull requests

### Development Setup

1. **Fork and Clone**
   ```bash
   # Fork the repository on GitHub
   git clone https://github.com/YOUR_USERNAME/nix-helm-generator-project.git
   cd nix-helm-generator-project
   ```

2. **Enter Development Environment**
   ```bash
   # This provides all necessary tools
   nix develop
   ```

3. **Verify Setup**
   ```bash
   # Run tests to ensure everything works
   nix flake check
   ./cicd/test/validate-charts.sh
   ```

## 🔄 Development Workflow

### Making Changes

1. **Create a Branch**
   ```bash
   git checkout -b feature/my-new-feature
   # or
   git checkout -b fix/issue-description
   ```

2. **Make Your Changes**
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

3. **Test Your Changes**
   ```bash
   # Run validation
   nix flake check
   
   # Test chart generation
   ./cicd/test/validate-charts.sh
   
   # Run integration tests
   ./cicd/test/integration-test.sh
   ```

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   # or
   git commit -m "fix: resolve issue with specific component"
   ```

### Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `refactor:` - Code refactoring
- `ci:` - CI/CD changes
- `chore:` - Maintenance tasks

Examples:
```
feat: add multi-chart dependency support
fix: resolve resource validation for StatefulSets
docs: update API reference for production features
test: add integration tests for multi-environment setups
```

## 📁 Project Structure

Understanding the codebase structure:

```
nix-helm-generator/
├── lib/                    # Core library code
│   ├── default.nix        # Main entry point
│   ├── chart.nix          # Single chart generation
│   ├── multi-chart.nix    # Multi-chart support
│   ├── resources.nix      # Kubernetes resource templates
│   ├── production.nix     # Production features
│   ├── validation.nix     # Input validation
│   └── shared.nix         # Shared utilities
├── examples/              # Example configurations
│   ├── nginx.nix         # Basic examples
│   ├── postgres.nix      # Database examples
│   └── multi-chart-app.nix # Multi-chart examples
├── tests/                 # Test suite
├── cicd/                  # CI/CD scripts
│   ├── test/             # Validation scripts
│   └── jenkins/          # Jenkins pipeline
├── docs/                  # Documentation
└── .github/              # GitHub workflows
```

## 🧪 Testing Guidelines

### Adding Tests

1. **Unit Tests**: Add to `tests/` directory
2. **Integration Tests**: Update `cicd/test/integration-test.sh`
3. **Example Tests**: Add new examples to `examples/`

### Test Categories

- **Validation Tests**: Chart structure and content validation
- **Generation Tests**: Test chart generation from Nix expressions
- **Kubernetes Tests**: Validate generated manifests against K8s API
- **Performance Tests**: Ensure generation speed and memory usage

### Running Tests

```bash
# Full test suite
nix flake check

# Validation tests
./cicd/test/validate-charts.sh

# Integration tests
./cicd/test/integration-test.sh

# Specific example
nix build .#examples
```

## 📝 Documentation

### What to Document

- **API Changes**: Update `docs/API_REFERENCE.md`
- **New Features**: Add examples and usage guide entries
- **Configuration Options**: Document all new parameters
- **Breaking Changes**: Update `CHANGELOG.md`

### Documentation Style

- Use clear, concise language
- Provide practical examples
- Include both basic and advanced use cases
- Add troubleshooting information when relevant

## 🎨 Code Style

### Nix Code Style

- Use 2-space indentation
- Follow nixpkgs conventions
- Comment complex logic
- Use meaningful variable names
- Group related functions

Example:
```nix
# Good
{
  mkDeployment = { name, image, ports ? [], replicas ? 1 }: {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata = {
      name = name;
      labels.app = name;
    };
    spec = {
      inherit replicas;
      selector.matchLabels.app = name;
      template = {
        metadata.labels.app = name;
        spec.containers = [{
          inherit name image;
          ports = map (port: { containerPort = port; }) ports;
        }];
      };
    };
  };
}
```

### Script Style (Bash)

- Use `#!/usr/bin/env bash`
- Set `set -e` for error handling
- Quote variables: `"$variable"`
- Use functions for reusable code

## 🚦 Pull Request Process

### Before Submitting

1. **Rebase on Latest Main**
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Run All Tests**
   ```bash
   nix flake check
   ```

3. **Update Documentation**
   - Add/update examples if needed
   - Update API docs for new functions
   - Add changelog entry for significant changes

### Pull Request Template

When submitting a PR, include:

- **Description**: What does this change do?
- **Motivation**: Why is this change needed?
- **Testing**: How was this tested?
- **Breaking Changes**: Any backwards compatibility issues?
- **Related Issues**: Link to relevant issues

### Review Process

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one maintainer review
3. **Testing**: Manual testing if needed
4. **Documentation**: Ensure docs are updated
5. **Merge**: Squash and merge when approved

## 🐛 Reporting Issues

### Bug Reports

Please include:
- **Description**: Clear description of the issue
- **Reproduction Steps**: How to reproduce the bug
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: Nix version, OS, etc.
- **Examples**: Minimal example that shows the issue

Use this template:
```markdown
**Bug Description**
A clear and concise description of the bug.

**To Reproduce**
Steps to reproduce the behavior:
1. Create a chart with '...'
2. Run 'nix build ...'
3. See error

**Expected Behavior**
A clear description of what you expected to happen.

**Environment**
- Nix version: [e.g. 2.15.0]
- OS: [e.g. Ubuntu 22.04]
- flake-utils version: [e.g. latest]

**Additional Context**
Add any other context about the problem here.
```

### Feature Requests

Please include:
- **Description**: What feature would you like?
- **Use Case**: Why do you need this feature?
- **Alternatives**: What alternatives have you considered?
- **Examples**: How would you use this feature?

## 🏷️ Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes

### Release Steps

1. Update `CHANGELOG.md`
2. Update version in `flake.nix` if applicable
3. Create release tag
4. Update documentation
5. Announce release

## 💬 Community

### Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community chat
- **Documentation**: Check docs first

### Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](./CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## 🎉 Recognition

Contributors are recognized in:
- `CHANGELOG.md` for significant contributions
- GitHub contributors page
- Release notes for major features

---

Thank you for contributing to Nix Helm Generator! Your contributions help make Kubernetes deployments more declarative and reliable.