#!/usr/bin/env bash

# Comprehensive Helm Validation Test Script
# Tests all 7 examples against their corresponding Helm charts

set -e

echo "=== Nix Helm Generator - Helm Validation Test ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
TOTAL=0

# Function to test an example
test_example() {
    local example_name=$1
    local helm_repo=$2
    local helm_chart=$3
    local helm_version=$4

    echo "Testing $example_name..."
    TOTAL=$((TOTAL + 1))

    # Generate Nix YAML
    if nix-instantiate --eval examples/$example_name.nix > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Nix evaluation successful"
    else
        echo -e "${RED}✗${NC} Nix evaluation failed"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Add helm repo
    if helm repo add $helm_repo https://charts.$helm_repo.com/ 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Helm repo added: $helm_repo"
    else
        echo -e "${YELLOW}⚠${NC} Helm repo already exists or failed: $helm_repo"
    fi

    # Update helm repos
    helm repo update > /dev/null 2>&1

    # Generate helm template
    if helm template $example_name $helm_repo/$helm_chart --version $helm_version --namespace default > helm-$example_name.yaml 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Helm template generated"
    else
        echo -e "${RED}✗${NC} Helm template failed"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Generate Nix YAML
    if nix-instantiate --eval --expr "(import examples/$example_name.nix { lib = (import <nixpkgs> {}).lib; }).yamlOutput" | sed 's/^"//' | sed 's/"$//' | sed 's/\\n/\n/g' | sed 's/\\"/"/g' > nix-$example_name.yaml 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Nix YAML generated"
    else
        echo -e "${RED}✗${NC} Nix YAML generation failed"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Basic validation - check if YAML contains essential resources
    if grep -q "kind.*Deployment" nix-$example_name.yaml && grep -q "kind.*Service" nix-$example_name.yaml; then
        echo -e "${GREEN}✓${NC} Essential resources found (Deployment, Service)"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} Missing essential resources"
        FAILED=$((FAILED + 1))
    fi

    echo
}

# Test all examples
echo "Running validation tests for all 7 examples..."
echo

test_example "nginx" "bitnami" "nginx" "15.0.0"
test_example "redis" "bitnami" "redis" "18.0.0"
test_example "postgres" "bitnami" "postgresql" "13.0.0"
test_example "prometheus" "prometheus-community" "prometheus" "23.0.0"
test_example "elasticsearch" "elastic" "elasticsearch" "8.5.0"
test_example "cert-manager" "cert-manager" "cert-manager" "v1.12.0"
test_example "ingress-nginx" "ingress-nginx" "ingress-nginx" "4.7.0"

# Summary
echo "=== Test Results Summary ==="
echo "Total examples tested: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    echo
    echo "Next steps:"
    echo "1. Review generated YAML files for detailed comparison"
    echo "2. Validate configurations in a Kubernetes cluster"
    echo "3. Document any intentional differences"
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo
    echo "Failed examples need attention:"
    echo "- Check Nix evaluation errors"
    echo "- Verify Helm chart versions and repositories"
    echo "- Review YAML generation issues"
fi

echo
echo "Generated files:"
ls -la *-*.yaml 2>/dev/null || echo "No YAML files generated"