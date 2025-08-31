#!/bin/bash

set -e

echo "🔍 Starting Nix Helm Chart Validation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if nix is available
if ! command -v nix &> /dev/null; then
    print_error "Nix is not installed or not in PATH"
    exit 1
fi

# Validate flake
print_status "Validating Nix flake..."
if nix flake check; then
    print_status "Flake validation passed"
else
    print_error "Flake validation failed"
    exit 1
fi

# Test chart generation
print_status "Testing chart generation..."
if nix eval --json .#my-app > /tmp/test-charts.json; then
    print_status "Chart generation successful"
else
    print_error "Chart generation failed"
    exit 1
fi

# Validate JSON structure
print_status "Validating JSON structure..."
if jq empty /tmp/test-charts.json; then
    print_status "JSON structure is valid"
else
    print_error "Invalid JSON structure"
    exit 1
fi

  # Test Kubernetes manifest validation
  print_status "Testing Kubernetes manifest validation..."
  if bash ./cicd/test/validate-manifests.sh /tmp/test-charts.json; then
    print_status "Kubernetes manifests are valid"
  else
    print_error "Kubernetes manifest validation failed"
    exit 1
  fi

# Test multi-chart support
print_status "Testing multi-chart support..."
if nix eval --json .#multi-app > /tmp/test-multi-charts.json; then
    print_status "Multi-chart generation successful"
else
    print_error "Multi-chart generation failed"
    exit 1
fi

# Clean up
rm -f /tmp/test-charts.json /tmp/test-multi-charts.json

print_status "All validations passed! 🎉"
echo "📊 Test Results: $(date)" > test-results.txt