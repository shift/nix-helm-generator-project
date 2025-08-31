# CI/CD Integration Guide

This guide covers integrating the Nix Helm Generator into various CI/CD platforms and GitOps workflows.

## Table of Contents

- [GitHub Actions](#github-actions)
- [ArgoCD/GitOps](#argocdgitops)
- [Jenkins](#jenkins)
- [GitLab CI/CD](#gitlab-cicd)
- [Testing Framework](#testing-framework)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## GitHub Actions

### Basic Deployment Workflow

```yaml
name: Deploy with Nix Helm Generator
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nixbuild/nix-quick-install-action@v28
      - name: Test Nix Helm Generator
        run: nix develop -c -- nix flake check

  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: nixbuild/nix-quick-install-action@v28
      - name: Generate Charts
        run: nix develop -c -- nix eval --json .#my-app > charts.json
      - name: Deploy to Kubernetes
        uses: azure/k8s-deploy@v4
        with:
          manifests: charts.json
          images: |
            my-app:${{ github.sha }}
```

### Environment Variables

Set these secrets in your GitHub repository:

- `KUBECONFIG`: Kubernetes configuration
- `DOCKER_REGISTRY`: Container registry URL
- `DOCKER_USERNAME`: Registry username
- `DOCKER_PASSWORD`: Registry password

## ArgoCD/GitOps

### Application Manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nix-helm-generator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/nix-helm-charts
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Multi-Environment ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nix-helm-multi-env
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: dev
      - env: staging
        namespace: staging
      - env: prod
        namespace: prod
  template:
    metadata:
      name: 'nix-helm-{{env}}'
    spec:
      source:
        helm:
          valueFiles:
          - values-{{env}}.yaml
      destination:
        namespace: '{{namespace}}'
```

## Jenkins

### Pipeline Configuration

```groovy
pipeline {
    agent any

    environment {
        NIX_PATH = 'nixpkgs=channel:nixos-unstable'
    }

    stages {
        stage('Generate Charts') {
            steps {
                sh 'nix develop -c -- nix eval --json .#my-app > charts.json'
            }
        }

        stage('Deploy') {
            steps {
                sh 'kubectl apply -f charts.json'
            }
        }
    }
}
```

### Shared Library Usage

```groovy
@Library('nix-helm-lib') _

pipeline {
    agent any

    stages {
        stage('Setup') {
            steps {
                script {
                    nixHelm = new NixHelmLib(this)
                    nixHelm.setupNix()
                }
            }
        }

        stage('Generate') {
            steps {
                script {
                    nixHelm.generateCharts('my-app')
                }
            }
        }
    }
}
```

## GitLab CI/CD

### Complete Pipeline

```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  image: nixos/nix:latest
  script:
    - nix flake check

build:
  stage: build
  script:
    - nix eval --json .#my-app > charts.json
  artifacts:
    paths:
      - charts.json

deploy_prod:
  stage: deploy
  script:
    - kubectl apply -f charts.json
  environment:
    name: production
  when: manual
```

### Variables

Set these CI/CD variables:

- `KUBE_CONFIG`: Base64 encoded kubeconfig
- `GCP_PROJECT_ID`: Google Cloud Project ID
- `GCP_ZONE`: Google Cloud Zone

## Testing Framework

### Running Tests

```bash
# Run all validations
./cicd/test/validate-charts.sh

# Validate Kubernetes manifests
./cicd/test/validate-manifests.sh charts.json

# Run integration tests
./cicd/test/integration-test.sh
```

### Test Structure

```
cicd/test/
├── validate-charts.sh      # Main validation script
├── validate-manifests.sh   # K8s manifest validation
└── integration-test.sh     # End-to-end testing
```

## Best Practices

### 1. Environment Separation

- Use separate namespaces for different environments
- Implement proper RBAC controls
- Use environment-specific values files

### 2. Security

- Store secrets in secure vaults (Vault, AWS Secrets Manager, etc.)
- Use short-lived credentials
- Implement image scanning in your pipeline

### 3. Monitoring

- Monitor deployment status
- Set up alerts for failed deployments
- Track performance metrics

### 4. Rollback Strategy

- Keep previous versions of manifests
- Implement canary deployments
- Use feature flags for gradual rollouts

## Troubleshooting

### Common Issues

#### Nix Cache Issues
```bash
# Clear nix cache
nix-collect-garbage -d

# Use cachix for faster builds
cachix use nix-community
```

#### Kubernetes Authentication
```bash
# Update kubeconfig
kubectl config set-context --current --namespace=your-namespace

# Test connection
kubectl cluster-info
```

#### Chart Generation Failures
```bash
# Debug nix evaluation
nix eval .#my-app --show-trace

# Check flake.lock
nix flake metadata
```

### Debug Commands

```bash
# Validate flake
nix flake check

# Test chart generation
nix eval --json .#my-app

# Dry-run deployment
kubectl apply --dry-run=client -f charts.json
```

## Platform-Specific Setup

### AWS EKS

```yaml
# GitHub Actions
- name: Configure AWS
  uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1

- name: Deploy to EKS
  run: |
    aws eks update-kubeconfig --name my-cluster
    kubectl apply -f charts.json
```

### Google GKE

```yaml
# GitLab CI/CD
deploy_gke:
  image: google/cloud-sdk:alpine
  script:
    - gcloud container clusters get-credentials my-cluster
    - kubectl apply -f charts.json
```

### Azure AKS

```yaml
# Jenkins Pipeline
stage('Deploy to AKS') {
    steps {
        sh '''
            az aks get-credentials --resource-group myRG --name myAKS
            kubectl apply -f charts.json
        '''
    }
}
```

## Contributing

When adding new CI/CD integrations:

1. Update this documentation
2. Add platform-specific examples
3. Include troubleshooting sections
4. Test the integration thoroughly

## Support

For issues and questions:

- Check the troubleshooting section
- Review existing GitHub issues
- Create a new issue with detailed information
- Include logs and configuration when possible