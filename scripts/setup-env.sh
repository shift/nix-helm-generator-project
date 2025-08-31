#!/bin/bash

set -e

# Environment setup script for Nix Helm Generator
# Usage: ./scripts/setup-env.sh <environment>

ENVIRONMENT=${1:-dev}

echo "🔧 Setting up $ENVIRONMENT environment..."

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

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod"
    exit 1
fi

# Environment-specific configurations
case $ENVIRONMENT in
    dev)
        NAMESPACE="dev"
        REPLICAS=1
        RESOURCES_REQUESTS_CPU="100m"
        RESOURCES_REQUESTS_MEMORY="128Mi"
        RESOURCES_LIMITS_CPU="500m"
        RESOURCES_LIMITS_MEMORY="512Mi"
        ;;
    staging)
        NAMESPACE="staging"
        REPLICAS=2
        RESOURCES_REQUESTS_CPU="200m"
        RESOURCES_REQUESTS_MEMORY="256Mi"
        RESOURCES_LIMITS_CPU="1000m"
        RESOURCES_LIMITS_MEMORY="1Gi"
        ;;
    prod)
        NAMESPACE="prod"
        REPLICAS=3
        RESOURCES_REQUESTS_CPU="500m"
        RESOURCES_REQUESTS_MEMORY="512Mi"
        RESOURCES_LIMITS_CPU="2000m"
        RESOURCES_LIMITS_MEMORY="2Gi"
        ;;
esac

# Create namespace if it doesn't exist
print_status "Ensuring namespace exists: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create environment-specific values file
VALUES_FILE="values-$ENVIRONMENT.yaml"
print_status "Creating environment values file: $VALUES_FILE"

cat > $VALUES_FILE << EOF
# Environment-specific values for $ENVIRONMENT
environment: $ENVIRONMENT
namespace: $NAMESPACE

replicaCount: $REPLICAS

resources:
  requests:
    cpu: $RESOURCES_REQUESTS_CPU
    memory: $RESOURCES_REQUESTS_MEMORY
  limits:
    cpu: $RESOURCES_LIMITS_CPU
    memory: $RESOURCES_LIMITS_MEMORY

# Environment-specific configurations
EOF

case $ENVIRONMENT in
    dev)
        cat >> $VALUES_FILE << EOF
ingress:
  enabled: false

service:
  type: ClusterIP

# Development-specific settings
debug: true
logLevel: debug
EOF
        ;;
    staging)
        cat >> $VALUES_FILE << EOF
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: staging.example.com
      paths:
        - path: /
          pathType: Prefix

service:
  type: ClusterIP

# Staging-specific settings
debug: false
logLevel: info
EOF
        ;;
    prod)
        cat >> $VALUES_FILE << EOF
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: example-tls
      hosts:
        - example.com

service:
  type: LoadBalancer

# Production-specific settings
debug: false
logLevel: warn

# High availability settings
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - my-app
        topologyKey: kubernetes.io/hostname

tolerations:
- key: "node-type"
  operator: "Equal"
  value: "production"
  effect: "NoSchedule"
EOF
        ;;
esac

print_status "Environment values file created: $VALUES_FILE"

# Set up RBAC if needed
print_status "Setting up RBAC for $ENVIRONMENT environment"

# Create service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nix-helm-deployer
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nix-helm-deployer
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nix-helm-deployer
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: nix-helm-deployer
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: nix-helm-deployer
  apiGroup: rbac.authorization.k8s.io
EOF

print_status "RBAC setup completed"

# Create environment-specific secrets/configmaps if needed
print_status "Setting up environment-specific configurations"

# Database configuration (example)
kubectl create secret generic db-config \
  --from-literal=host=db-$ENVIRONMENT.example.com \
  --from-literal=port=5432 \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

print_status "Environment setup completed! 🎉"
echo "📊 Environment Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Namespace: $NAMESPACE"
echo "  Replicas: $REPLICAS"
echo "  Values file: $VALUES_FILE"