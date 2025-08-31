#!/bin/bash

set -e

# Rollback script for Nix Helm Generator
# Usage: ./scripts/rollback.sh <environment> [backup-file]

ENVIRONMENT=${1:-dev}
BACKUP_FILE=${2:-}
NAMESPACE=${3:-default}

echo "🔄 Rolling back deployment in $ENVIRONMENT environment..."

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

# Find latest backup if not specified
if [ -z "$BACKUP_FILE" ]; then
    BACKUP_FILE=$(ls -t backup-*.json 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        print_error "No backup files found"
        exit 1
    fi
fi

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

print_status "Using backup file: $BACKUP_FILE"

# Confirm rollback
echo "⚠️  This will rollback to the state saved in $BACKUP_FILE"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Rollback cancelled"
    exit 0
fi

# Perform rollback
print_status "Performing rollback..."

# Delete current resources
print_status "Removing current deployment..."
kubectl delete -f charts.json -n $NAMESPACE --ignore-not-found=true || true

# Wait for deletion
sleep 5

# Restore from backup
print_status "Restoring from backup..."
kubectl apply -f $BACKUP_FILE -n $NAMESPACE

# Wait for restoration
print_status "Waiting for restoration to complete..."
sleep 10

# Check status
if kubectl get pods -n $NAMESPACE --no-headers | grep -v Running > /dev/null; then
    print_warning "Some pods may not be fully restored"
    kubectl get pods -n $NAMESPACE
else
    print_status "Restoration completed successfully"
fi

print_status "Rollback completed! 🎉"
echo "📊 Rollback Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Namespace: $NAMESPACE"
echo "  Backup used: $BACKUP_FILE"