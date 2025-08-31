{ lib }:

let
  # Shared resource types
  resourceTypes = {
    namespace = "Namespace";
    configmap = "ConfigMap";
    secret = "Secret";
    serviceaccount = "ServiceAccount";
    clusterrole = "ClusterRole";
    clusterrolebinding = "ClusterRoleBinding";
    rbac = "RBAC";
  };

  # Validate shared resource configuration
  validateSharedResource = resource:
    let
      required = ["type" "name"];
      missing = lib.filter (field: !resource ? ${field}) required;
      validTypes = lib.attrNames resourceTypes;
    in
    if missing != []
    then throw "Shared resource missing required fields: ${lib.concatStringsSep ", " missing}"
    else if !lib.elem resource.type validTypes
    then throw "Invalid shared resource type '${resource.type}'. Valid types: ${lib.concatStringsSep ", " validTypes}"
    else resource;

  # Generate shared namespace
  mkSharedNamespace = config:
    let
      name = config.name or "default";
      labels = config.labels or {};
      annotations = config.annotations or {};
    in
    {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        name = name;
        labels = labels // {
          "app.kubernetes.io/managed-by" = "nix-helm-generator";
          "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
        };
        annotations = annotations;
      };
    };

  # Generate shared ConfigMap
  mkSharedConfigMap = config:
    let
      name = config.name;
      namespace = config.namespace or "default";
      data = config.data or {};
      labels = config.labels or {};
    in
    {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels // {
          "app.kubernetes.io/managed-by" = "nix-helm-generator";
          "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
        };
      };
      data = data;
    };

  # Generate shared Secret
  mkSharedSecret = config:
    let
      name = config.name;
      namespace = config.namespace or "default";
      type = config.type or "Opaque";
      data = config.data or {};
      labels = config.labels or {};
    in
    {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels // {
          "app.kubernetes.io/managed-by" = "nix-helm-generator";
          "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
        };
      };
      type = type;
      data = data;
    };

  # Generate shared ServiceAccount
  mkSharedServiceAccount = config:
    let
      name = config.name;
      namespace = config.namespace or "default";
      labels = config.labels or {};
    in
    {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels // {
          "app.kubernetes.io/managed-by" = "nix-helm-generator";
          "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
        };
      };
    };

  # Generate shared RBAC resources
  mkSharedRBAC = config:
    let
      name = config.name;
      namespace = config.namespace or "default";
      rules = config.rules or [];
      subjects = config.subjects or [];
      labels = config.labels or {};

      clusterRole = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = {
          name = name;
          labels = labels // {
            "app.kubernetes.io/managed-by" = "nix-helm-generator";
            "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
          };
        };
        rules = rules;
      };

      clusterRoleBinding = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          name = name;
          labels = labels // {
            "app.kubernetes.io/managed-by" = "nix-helm-generator";
            "app.kubernetes.io/part-of" = config.appName or "multi-chart-app";
          };
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = name;
        };
        subjects = subjects;
      };
    in [clusterRole clusterRoleBinding];

  # Generate resource based on type
  generateSharedResource = resourceConfig:
    let
      validated = validateSharedResource resourceConfig;
      type = validated.type;
    in
    if type == "namespace"
    then mkSharedNamespace validated
    else if type == "configmap"
    then mkSharedConfigMap validated
    else if type == "secret"
    then mkSharedSecret validated
    else if type == "serviceaccount"
    then mkSharedServiceAccount validated
    else if type == "rbac"
    then mkSharedRBAC validated
    else throw "Unsupported shared resource type: ${type}";

  # Generate all shared resources
  mkSharedResources = sharedConfig:
    let
      resources = sharedConfig.resources or [];
      appName = sharedConfig.appName or "multi-chart-app";
      namespace = sharedConfig.namespace or "default";

      # Add appName and namespace to each resource config
      enrichedConfigs = lib.map (config:
        config // { inherit appName namespace; }
      ) resources;

      # Generate each resource
      generated = lib.map generateSharedResource enrichedConfigs;

      # Flatten RBAC resources (they return arrays)
      flattened = lib.flatten generated;

    in flattened;

  # Merge shared resources into chart configurations
  mergeSharedIntoCharts = sharedResources: charts:
    lib.mapAttrs (chartName: chartConfig:
      chartConfig // {
        # Add shared resources reference
        sharedResources = sharedResources;
      }
    ) charts;

in
{
  inherit
    resourceTypes
    validateSharedResource
    mkSharedNamespace
    mkSharedConfigMap
    mkSharedSecret
    mkSharedServiceAccount
    mkSharedRBAC
    generateSharedResource
    mkSharedResources
    mergeSharedIntoCharts;
}