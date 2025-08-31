{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;

  # Import the library
  nix-helm-generator = import ./lib {};

  # Test topological sort functionality
  testTopologicalSort = let
    charts = {
      api = { name = "api"; version = "1.0.0"; };
      web = { name = "web"; version = "1.0.0"; };
      db = { name = "db"; version = "1.0.0"; };
    };

    dependencies = [
      { name = "db"; }
      { name = "api"; }
      { name = "web"; }
    ];

    values = {
      api = { enabled = true; };
      web = { enabled = true; };
      db = { enabled = true; };
    };

    result = nix-helm-generator.dependency.resolveAllDependencies charts dependencies values;
  in {
    sorted = result.sorted;
    hasDuplicates = lib.length result.sorted != lib.length (lib.unique result.sorted);
    correctOrder = result.sorted == ["db" "api" "web"];
  };

  # Test RBAC shared resources
  testRBACSharedResources = let
    sharedConfig = {
      appName = "test-app";
      namespace = "test";
      resources = [
        {
          type = "rbac";
          name = "test-rbac";
          rules = [
            {
              apiGroups = [""];
              resources = ["pods"];
              verbs = ["get" "list"];
            }
          ];
          subjects = [
            {
              kind = "ServiceAccount";
              name = "test-sa";
              namespace = "test";
            }
          ];
        }
      ];
    };

    result = nix-helm-generator.shared.mkSharedResources sharedConfig;
  in {
    generated = result;
    hasClusterRole = lib.any (r: r.kind == "ClusterRole") result;
    hasClusterRoleBinding = lib.any (r: r.kind == "ClusterRoleBinding") result;
    clusterRoleName = let
      clusterRole = lib.findFirst (r: r.kind == "ClusterRole") null result;
    in if clusterRole != null then clusterRole.metadata.name else null;
  };

  # Test simple multi-chart generation
  testSimpleMultiChart = let
    config = {
      name = "simple-test-app";
      version = "1.0.0";
      charts = {
        api = {
          name = "api-service";
          version = "1.0.0";
          app = {
            name = "api";
            image = "nginx:alpine";
            ports = [80];
          };
          resources = {
            deployment = { replicas = 2; };
            service = {
              type = "ClusterIP";
              ports = [{ port = 80; targetPort = 80; }];
            };
          };
        };
        web = {
          name = "web-service";
          version = "1.0.0";
          app = {
            name = "web";
            image = "nginx:alpine";
            ports = [80];
          };
          resources = {
            deployment = { replicas = 1; };
            service = {
              type = "LoadBalancer";
              ports = [{ port = 80; targetPort = 80; }];
            };
          };
        };
      };
      dependencies = [
        { name = "api"; }
        { name = "web"; }
      ];
      global = {
        namespace = "default";
      };
    };

    result = nix-helm-generator.multi-chart.mkMultiChart config;
  in {
    generated = result;
    hasYamlOutput = result ? combinedYaml;
    yamlIsString = lib.isString result.combinedYaml;
    hasOrderedCharts = result ? orderedCharts;
    chartsGenerated = lib.length result.generatedCharts == 2;
  };

  # Test complex multi-chart with RBAC
  testComplexMultiChart = let
    config = {
      name = "complex-test-app";
      version = "1.0.0";
      charts = {
        database = {
          name = "postgres-db";
          version = "1.0.0";
          app = {
            name = "postgres";
            image = "postgres:15";
            ports = [5432];
          };
          resources = {
            deployment = { replicas = 1; };
            service = {
              type = "ClusterIP";
              ports = [{ port = 5432; targetPort = 5432; }];
            };
          };
        };
        backend = {
          name = "backend-api";
          version = "1.0.0";
          app = {
            name = "backend";
            image = "nginx:alpine";
            ports = [8080];
          };
          resources = {
            deployment = { replicas = 2; };
            service = {
              type = "ClusterIP";
              ports = [{ port = 8080; targetPort = 8080; }];
            };
          };
        };
      };
      dependencies = [
        { name = "database"; }
        { name = "backend"; }
      ];
      global = {
        namespace = "production";
      };
      shared = {
        appName = "complex-test-app";
        namespace = "production";
        resources = [
          {
            type = "namespace";
            name = "production";
          }
          {
            type = "rbac";
            name = "backend-rbac";
            rules = [
              {
                apiGroups = [""];
                resources = ["pods" "services"];
                verbs = ["get" "list"];
              }
            ];
            subjects = [
              {
                kind = "ServiceAccount";
                name = "backend-sa";
                namespace = "production";
              }
            ];
          }
        ];
      };
    };

    result = nix-helm-generator.multi-chart.mkMultiChart config;
  in {
    generated = result;
    hasSharedResources = result ? sharedResources;
    sharedResourcesCount = lib.length result.sharedResources;
    hasYamlOutput = result ? combinedYaml;
    yamlIsString = lib.isString result.combinedYaml;
  };

  # Test backward compatibility (single chart)
  testBackwardCompatibility = let
    singleChart = nix-helm-generator.mkChart {
      name = "single-app";
      version = "1.0.0";
      app = {
        image = "nginx:alpine";
        ports = [80];
      };
      resources = {
        deployment = { replicas = 1; };
        service = {
          type = "ClusterIP";
          ports = [{ port = 80; targetPort = 80; }];
        };
      };
    };
  in {
    generated = singleChart;
    hasYamlOutput = singleChart ? yamlOutput;
    yamlIsString = lib.isString singleChart.yamlOutput;
  };

  # Test error scenarios
  testErrorScenarios = let
    # Test circular dependency
    circularConfig = {
      name = "circular-test";
      charts = {
        a = { name = "a"; version = "1.0.0"; };
        b = { name = "b"; version = "1.0.0"; };
      };
      dependencies = [
        { name = "a"; }
        { name = "b"; }
        { name = "a"; } # This creates a cycle
      ];
    };

    # Test invalid shared resource type
    invalidSharedConfig = {
      name = "invalid-shared-test";
      charts = {
        test = { name = "test"; version = "1.0.0"; };
      };
      shared = {
        resources = [
          {
            type = "invalid-type";
            name = "test";
          }
        ];
      };
    };
  in {
    circularDependencyHandled = let
      result = builtins.tryEval (nix-helm-generator.multi-chart.mkMultiChart circularConfig);
    in !result.success;

    invalidSharedTypeHandled = let
      result = builtins.tryEval (nix-helm-generator.multi-chart.mkMultiChart invalidSharedConfig);
    in !result.success;
  };

in
{
  inherit
    testTopologicalSort
    testRBACSharedResources
    testSimpleMultiChart
    testComplexMultiChart
    testBackwardCompatibility
    testErrorScenarios;

  # Overall test results
  results = {
    topologicalSort = {
      passed = testTopologicalSort.correctOrder && !testTopologicalSort.hasDuplicates;
      details = testTopologicalSort;
    };

    rbacValidation = {
      passed = testRBACSharedResources.hasClusterRole && testRBACSharedResources.hasClusterRoleBinding;
      details = testRBACSharedResources;
    };

    simpleMultiChart = {
      passed = testSimpleMultiChart.hasYamlOutput && testSimpleMultiChart.yamlIsString && testSimpleMultiChart.chartsGenerated;
      details = testSimpleMultiChart;
    };

    complexMultiChart = {
      passed = testComplexMultiChart.hasYamlOutput && testComplexMultiChart.yamlIsString && testComplexMultiChart.hasSharedResources;
      details = testComplexMultiChart;
    };

    backwardCompatibility = {
      passed = testBackwardCompatibility.hasYamlOutput && testBackwardCompatibility.yamlIsString;
      details = testBackwardCompatibility;
    };

    errorHandling = {
      passed = testErrorScenarios.circularDependencyHandled && testErrorScenarios.invalidSharedTypeHandled;
      details = testErrorScenarios;
    };
  };

  # Summary
  summary = {
    totalTests = 6;
    passedTests = lib.length (lib.filter (test: test.passed) (lib.attrValues results));
    allPassed = lib.all (test: test.passed) (lib.attrValues results);
  };
}