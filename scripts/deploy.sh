#!/bin/bash

set -e

# Deployment script for Nix Helm Generator
# Usage: ./scripts/deploy.sh <environment> <app-name>

ENVIRONMENT=${1:-dev}
APP_NAME=${2:-my-app}
NAMESPACE=${3:-default}

echo "🚀 Deploying $APP_NAME to $ENVIRONMENT environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod"
    exit 1
fi

# Set environment-specific variables
case $ENVIRONMENT in
    dev)
        NAMESPACE="dev"
        ;;
    staging)
        NAMESPACE="staging"
        ;;
    prod)
        NAMESPACE="prod"
        ;;
esac

# Generate charts
print_status "Generating charts for $APP_NAME..."
if nix develop -c -- nix eval --json .#$APP_NAME > charts.json; then
    print_status "Charts generated successfully"
else
    print_error "Failed to generate charts"
    exit 1
fi

# Validate manifests
print_status "Validating Kubernetes manifests..."
if nix develop -c -- ./cicd/test/validate-manifests.sh charts.json; then
    print_status "Manifests validation passed"
else
    print_error "Manifest validation failed"
    exit 1
fi

# Backup current state (for rollback)
BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).json"
print_status "Creating backup..."
kubectl get all -n $NAMESPACE -o json > $BACKUP_FILE 2>/dev/null || true
print_status "Backup created: $BACKUP_FILE"

# Deploy to Kubernetes
print_status "Deploying to Kubernetes namespace: $NAMESPACE..."
if kubectl apply -f charts.json -n $NAMESPACE; then
    print_status "Deployment successful"
else
    print_error "Deployment failed"
    exit 1
fi

# Wait for rollout
print_status "Waiting for rollout to complete..."
if kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s; then
    print_status "Rollout completed successfully"
else
    print_warning "Rollout timed out or failed - manual intervention may be required"
fi

# Health check
print_status "Performing health checks..."
sleep 10

# Check pod status
if kubectl get pods -n $NAMESPACE -l app=$APP_NAME --no-headers | grep -v Running > /dev/null; then
    print_warning "Some pods are not in Running state"
    kubectl get pods -n $NAMESPACE -l app=$APP_NAME
else
    print_status "All pods are running"
fi

# Clean up old backups (keep last 5)
print_status "Cleaning up old backups..."
ls -t backup-*.json 2>/dev/null | tail -n +6 | xargs -r rm || true

print_status "Deployment completed! 🎉"
echo "📊 Deployment Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Namespace: $NAMESPACE"
echo "  App: $APP_NAME"
echo "  Backup: $BACKUP_FILE"