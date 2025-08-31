#!/usr/bin/env bash

# Simple validation test for all 7 examples

echo "=== Simple Nix Helm Generator Validation Test ==="
echo

PASSED=0
FAILED=0
TOTAL=0

examples=("nginx" "redis" "postgres" "prometheus" "elasticsearch" "cert-manager" "ingress-nginx")

for example in "${examples[@]}"; do
    echo "Testing $example..."
    TOTAL=$((TOTAL + 1))

    # Test Nix evaluation
    if nix-instantiate --eval --expr "(import examples/$example.nix { lib = (import <nixpkgs> {}).lib; }).yamlOutput" > /dev/null 2>&1; then
        echo "  ✓ Nix evaluation successful"

        # Test YAML generation and basic structure
        yaml_output=$(nix-instantiate --eval --expr "(import examples/$example.nix { lib = (import <nixpkgs> {}).lib; }).yamlOutput" 2>/dev/null)
        resource_count=$(echo "$yaml_output" | grep -o 'kind' | wc -l)
        if [[ -n "$yaml_output" ]] && [[ $resource_count -gt 0 ]]; then
            echo "  ✓ YAML contains Kubernetes resources"
            PASSED=$((PASSED + 1))
        else
            echo "  ✗ YAML missing or malformed"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  ✗ Nix evaluation failed"
        FAILED=$((FAILED + 1))
    fi
    echo
done

echo "=== Results ==="
echo "Total: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo "🎉 All tests passed!"
else
    echo "❌ Some tests failed"
fi