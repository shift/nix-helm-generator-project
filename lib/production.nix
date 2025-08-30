{ lib }:

let
  # API Version detection and compatibility (shared with resources.nix)
  getApiVersions = config:
    let
      k8sVersion = config.kubernetesVersion or "1.25.0";
      versionParts = lib.splitString "." k8sVersion;
      major = lib.toInt (lib.head versionParts);
      minor = lib.toInt (lib.head (lib.tail versionParts));
    in
    {
      inherit k8sVersion major minor;

      # API version mappings based on Kubernetes version
      networkingApiVersion = if minor >= 19 then "networking.k8s.io/v1" else "networking.k8s.io/v1beta1";
      policyApiVersion = if minor >= 21 then "policy/v1" else "policy/v1beta1";
      appsApiVersion = "apps/v1";  # Stable since 1.9
      coreApiVersion = "v1";
    };

  # Generate Pod Disruption Budget
  mkPDB = config: appConfig:
    let
      pdbConfig = appConfig.production.pdb or {};
      enabled = pdbConfig.enabled or false;
      minAvailable = pdbConfig.minAvailable or "50%";
      maxUnavailable = pdbConfig.maxUnavailable or null;
      labels = config.labels or { app = config.name; };
      apiVersions = getApiVersions config;
    in
    if !enabled then null else {
      apiVersion = apiVersions.policyApiVersion;
      kind = "PodDisruptionBudget";
      metadata = {
        name = "${config.name}-pdb";
        namespace = config.namespace or "default";
        labels = labels;
      };
      spec = {
        minAvailable = minAvailable;
      } // (if maxUnavailable != null then { maxUnavailable = maxUnavailable; } else {})
        // {
          selector = {
            matchLabels = labels;
          };
        };
    };

  # Apply resource limits and requests to containers
  applyResources = appConfig: containers:
    let
      resources = appConfig.production.resources or {};
      requests = resources.requests or {};
      limits = resources.limits or {};
    in
    if resources == {} then containers else
      lib.map (container: container // {
        resources = {
          requests = requests;
          limits = limits;
        };
      }) containers;

  # Apply health checks to containers
  applyHealthChecks = appConfig: containers:
    let
      healthChecks = appConfig.production.healthChecks or {};
      readinessProbe = healthChecks.readinessProbe or null;
      livenessProbe = healthChecks.livenessProbe or null;
    in
    if healthChecks == {} then containers else
      lib.map (container: container //
        (if readinessProbe != null then { inherit readinessProbe; } else {}) //
        (if livenessProbe != null then { inherit livenessProbe; } else {})
      ) containers;

  # Apply security context
  applySecurityContext = appConfig: spec:
    let
      securityConfig = appConfig.production.securityContext or {};
      podSecurityContext = securityConfig.pod or {};
      containerSecurityContext = securityConfig.container or {};
    in
    if securityConfig == {} then spec else
      spec // {
        securityContext = podSecurityContext;
        containers = lib.map (container: container // {
          securityContext = containerSecurityContext;
        }) spec.containers;
      };

  # Generate NetworkPolicy
  mkNetworkPolicy = config: appConfig:
    let
      networkConfig = appConfig.production.networkPolicy or {};
      enabled = networkConfig.enabled or false;
      labels = config.labels or { app = config.name; };
      apiVersions = getApiVersions config;
    in
    if !enabled then null else {
      apiVersion = apiVersions.networkingApiVersion;
      kind = "NetworkPolicy";
      metadata = {
        name = "${config.name}-network-policy";
        namespace = config.namespace or "default";
        labels = labels;
      };
      spec = {
        podSelector = {
          matchLabels = labels;
        };
        policyTypes = ["Ingress" "Egress"];
        ingress = networkConfig.ingress or [
          {
            from = [
              {
                podSelector = {
                  matchLabels = labels;
                };
              }
            ];
          }
        ];
        egress = networkConfig.egress or [
          {}
        ];
      };
    };

  # Apply production features to existing resources
  mkProductionResources = config: resources:
    let
      appConfig = config.app or {};
      productionConfig = appConfig.production or {};

      # Enhanced deployment with production features
      enhancedDeployment =
        if resources ? deployment then
          let
            deployment = resources.deployment;
            containers = applyResources appConfig deployment.spec.template.spec.containers;
            containersWithHealth = applyHealthChecks appConfig containers;
            enhancedSpec = applySecurityContext appConfig deployment.spec.template.spec;
          in
          deployment // {
            spec = deployment.spec // {
              template = deployment.spec.template // {
                spec = enhancedSpec // {
                  containers = containersWithHealth;
                };
              };
            };
          }
        else null;

      # Generate additional production resources
      pdb = mkPDB config appConfig;
      networkPolicy = mkNetworkPolicy config appConfig;

      # Combine all resources
      productionResources = {
        deployment = enhancedDeployment;
        service = resources.service or null;
        configMap = resources.configMap or null;
        ingress = resources.ingress or null;
      } // (if pdb != null then { podDisruptionBudget = pdb; } else {})
        // (if networkPolicy != null then { networkPolicy = networkPolicy; } else {});

      # Filter out null values
      finalResources = lib.filterAttrs (name: value: value != null) productionResources;
    in
    finalResources;

in
{
  inherit mkPDB applyResources applyHealthChecks applySecurityContext mkNetworkPolicy mkProductionResources;
}