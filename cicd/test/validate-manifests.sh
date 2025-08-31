#!/bin/bash

set -e

MANIFEST_FILE=$1

if [ -z "$MANIFEST_FILE" ]; then
    echo "Usage: $0 <manifest-file>"
    exit 1
fi

echo "🔍 Validating Kubernetes manifests..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found, installing..."
    # This would be handled by the CI environment
    exit 1
fi

# Validate manifests using kubectl
if kubectl apply --dry-run=client -f "$MANIFEST_FILE" > /dev/null 2>&1; then
    echo "✓ Kubernetes manifests are valid"
    exit 0
else
    echo "✗ Kubernetes manifest validation failed"
    kubectl apply --dry-run=client -f "$MANIFEST_FILE"
    exit 1
fi