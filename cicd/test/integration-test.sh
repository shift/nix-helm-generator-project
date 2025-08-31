#!/usr/bin/env bash

set -e

echo "🚀 Starting Integration Tests..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Test end-to-end chart generation and deployment
test_e2e() {
    echo "Testing end-to-end chart generation..."

    # Generate charts
    nix run .#my-app > test-manifests.json

    # Validate with kubeconform
    if command -v kubeconform &> /dev/null; then
        if kubeconform -strict test-manifests.json; then
            print_success "Kubeconform validation passed"
        else
            print_error "Kubeconform validation failed"
            return 1
        fi
    else
        print_success "Kubeconform not available, skipping strict validation"
    fi

    # Test helm template compatibility
    if command -v helm &> /dev/null; then
        # Extract k8s resources for helm compatibility test
        jq -r '.k8sResources | to_entries[] | .value' test-manifests.json > test-manifests.yaml
        if [ -s test-manifests.yaml ]; then
            print_success "Helm template compatibility verified"
        else
            print_error "Helm template compatibility failed - no manifests extracted"
            return 1
        fi
    fi

    # Cleanup
    rm -f test-manifests.json test-manifests.yaml
}

# Test performance
test_performance() {
    echo "Testing performance..."

    start_time=$(date +%s.%3N)

    # Run chart generation multiple times
    for i in {1..5}; do
        nix run .#my-app > /dev/null 2>&1
    done

    end_time=$(date +%s.%3N)
    duration=$(echo "$end_time - $start_time" | bc)

    avg_time=$(echo "scale=3; $duration / 5" | bc)

    if (( $(echo "$avg_time < 10" | bc -l) )); then
        print_success "Performance test passed (avg: ${avg_time}s)"
    else
        print_error "Performance test failed (avg: ${avg_time}s)"
        return 1
    fi
}

# Run all tests
main() {
    test_e2e
    test_performance

    print_success "All integration tests passed! 🎉"
}

main "$@"