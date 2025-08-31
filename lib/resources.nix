{ lib }:

let
  # API Version detection and compatibility
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

  # Generate Deployment resource
  mkDeployment = config: appConfig:
    let
      name = config.name;
      namespace = config.namespace or "default";
      replicas = appConfig.replicas or 1;
      image = appConfig.image;
      ports = appConfig.ports or [];
      env = appConfig.env or {};
      labels = config.labels or { app = name; };
      apiVersions = getApiVersions config;
    in
    {
      apiVersion = apiVersions.appsApiVersion;
      kind = "Deployment";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        replicas = replicas;
        selector = {
          matchLabels = labels;
        };
        template = {
          metadata = {
            labels = labels;
          };
          spec = {
            containers = [
              {
                name = name;
                image = image;
                ports = lib.map (port: { containerPort = port; }) ports;
                env = lib.mapAttrsToList (name: value: { inherit name value; }) env;
              }
            ];
          };
        };
      };
    };

  # Generate Service resource
  mkService = config: appConfig:
    let
      name = config.name;
      namespace = config.namespace or "default";
      ports = appConfig.ports or [];
      labels = config.labels or { app = name; };
      serviceType = appConfig.serviceType or "ClusterIP";
    in
    {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        type = serviceType;
        selector = labels;
        ports = lib.map (port: {
          port = port;
          targetPort = port;
          protocol = "TCP";
        }) ports;
      };
    };

  # Generate ConfigMap resource
  mkConfigMap = config: appConfig:
    let
      name = config.name;
      namespace = config.namespace or "default";
      data = appConfig.configData or {};
      labels = config.labels or { app = name; };
    in
    if data == {} then null else {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "${name}-config";
        namespace = namespace;
        labels = labels;
      };
      data = data;
    };

  # Generate Ingress resource
  mkIngress = config: appConfig:
    let
      name = config.name;
      namespace = config.namespace or "default";
      ingressConfig = appConfig.ingress or {};
      enabled = ingressConfig.enabled or false;
      hosts = ingressConfig.hosts or [];
      tls = ingressConfig.tls or [];
      labels = config.labels or { app = name; };
      apiVersions = getApiVersions config;
    in
    if !enabled then null else {
      apiVersion = apiVersions.networkingApiVersion;
      kind = "Ingress";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
        annotations = ingressConfig.annotations or {};
      };
      spec = {
        ingressClassName = ingressConfig.className or null;
        rules = lib.map (host: {
          host = host;
          http = {
            paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend = {
                  service = {
                    name = name;
                    port = {
                      number = lib.head (appConfig.ports or [80]);
                    };
                  };
                };
              }
            ];
          };
        }) hosts;
        tls = tls;
      };
    };

  # Generate ServiceAccount resource
  mkServiceAccount = config: appConfig:
    let
      rbacConfig = appConfig.rbac or {};
      enabled = rbacConfig.serviceAccount.enabled or false;
      name = rbacConfig.serviceAccount.name or config.name;
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
    in
    if !enabled then null else {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
        annotations = rbacConfig.serviceAccount.annotations or {};
      };
      automountServiceAccountToken = rbacConfig.serviceAccount.automountServiceAccountToken or true;
    };

  # Generate Role resource
  mkRole = config: appConfig:
    let
      rbacConfig = appConfig.rbac or {};
      enabled = rbacConfig.role.enabled or false;
      name = rbacConfig.role.name or "${config.name}-role";
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
      rules = rbacConfig.role.rules or [];
    in
    if !enabled then null else {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "Role";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      rules = rules;
    };

  # Generate RoleBinding resource
  mkRoleBinding = config: appConfig:
    let
      rbacConfig = appConfig.rbac or {};
      enabled = rbacConfig.roleBinding.enabled or false;
      name = rbacConfig.roleBinding.name or "${config.name}-rolebinding";
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
      roleName = rbacConfig.roleBinding.roleName or "${config.name}-role";
      serviceAccountName = rbacConfig.roleBinding.serviceAccountName or config.name;
      subjects = rbacConfig.roleBinding.subjects or [
        {
          kind = "ServiceAccount";
          name = serviceAccountName;
          namespace = namespace;
        }
      ];
    in
    if !enabled then null else {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "RoleBinding";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "Role";
        name = roleName;
      };
      subjects = subjects;
    };

  # Generate StatefulSet resource
  mkStatefulSet = config: appConfig:
    let
      statefulSetConfig = appConfig.statefulSet or {};
      enabled = statefulSetConfig.enabled or false;
      name = config.name;
      namespace = config.namespace or "default";
      replicas = statefulSetConfig.replicas or 1;
      image = appConfig.image;
      ports = appConfig.ports or [];
      env = appConfig.env or {};
      labels = config.labels or { app = name; };
      serviceName = statefulSetConfig.serviceName or name;
      storageClassName = statefulSetConfig.storageClassName or null;
      storageSize = statefulSetConfig.storageSize or "10Gi";
    in
    if !enabled then null else {
      apiVersion = "apps/v1";
      kind = "StatefulSet";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        serviceName = serviceName;
        replicas = replicas;
        selector = {
          matchLabels = labels;
        };
        template = {
          metadata = {
            labels = labels;
          };
          spec = {
            containers = [
              {
                name = name;
                image = image;
                ports = lib.map (port: { containerPort = port; }) ports;
                env = lib.mapAttrsToList (name: value: { inherit name value; }) env;
                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/data";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim = {
                  claimName = "${name}-pvc";
                };
              }
            ];
          };
        };
        volumeClaimTemplates = [
          {
            metadata = {
              name = "data";
              namespace = namespace;
              labels = labels;
            };
            spec = {
              accessModes = ["ReadWriteOnce"];
              resources = {
                requests = {
                  storage = storageSize;
                };
              };
            } // (if storageClassName != null then { storageClassName = storageClassName; } else {});
          }
        ];
      };
    };

  # Generate PersistentVolumeClaim resource
  mkPVC = config: appConfig:
    let
      pvcConfig = appConfig.persistentVolumeClaim or {};
      enabled = pvcConfig.enabled or false;
      name = pvcConfig.name or "${config.name}-pvc";
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
      storageClassName = pvcConfig.storageClassName or null;
      storageSize = pvcConfig.storageSize or "10Gi";
      accessModes = pvcConfig.accessModes or ["ReadWriteOnce"];
    in
    if !enabled then null else {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        accessModes = accessModes;
        resources = {
          requests = {
            storage = storageSize;
          };
        };
      } // (if storageClassName != null then { storageClassName = storageClassName; } else {});
    };

  # Generate Secret resource
  mkSecret = config: appConfig:
    let
      secretConfig = appConfig.secret or {};
      enabled = secretConfig.enabled or false;
      name = secretConfig.name or "${config.name}-secret";
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
      type = secretConfig.type or "Opaque";
      data = secretConfig.data or {};
      stringData = secretConfig.stringData or {};
    in
    if !enabled then null else {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      type = type;
      data = data;
      stringData = stringData;
    };

  # Generate ServiceMonitor resource
  mkServiceMonitor = config: appConfig:
    let
      monitoringConfig = appConfig.monitoring or {};
      serviceMonitorConfig = monitoringConfig.serviceMonitor or {};
      enabled = serviceMonitorConfig.enabled or false;
      name = serviceMonitorConfig.name or "${config.name}-servicemonitor";
      namespace = config.namespace or "default";
      labels = config.labels or { app = config.name; };
      selectorLabels = serviceMonitorConfig.selectorLabels or labels;
      endpoints = serviceMonitorConfig.endpoints or [
        {
          port = "http";
          path = "/metrics";
          interval = "30s";
        }
      ];
    in
    if !enabled then null else {
      apiVersion = "monitoring.coreos.com/v1";
      kind = "ServiceMonitor";
      metadata = {
        name = name;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        selector = {
          matchLabels = selectorLabels;
        };
        endpoints = endpoints;
      };
    };

  # Main function to generate all resources
  mkResources = config:
    let
      appConfig = config.app or {};
      deployment = mkDeployment config appConfig;
      service = mkService config appConfig;
      configMap = mkConfigMap config appConfig;
      ingress = mkIngress config appConfig;
      serviceAccount = mkServiceAccount config appConfig;
      role = mkRole config appConfig;
      roleBinding = mkRoleBinding config appConfig;
      statefulSet = mkStatefulSet config appConfig;
      pvc = mkPVC config appConfig;
      secret = mkSecret config appConfig;
      serviceMonitor = mkServiceMonitor config appConfig;

      # Filter out null resources
      allResources = lib.filter (r: r != null) [
        deployment service configMap ingress serviceAccount
        role roleBinding statefulSet pvc secret serviceMonitor
      ];

      # Create a named set of resources
      resourceSet = {
        deployment = deployment;
        service = service;
      } // (if configMap != null then { configMap = configMap; } else {})
        // (if ingress != null then { ingress = ingress; } else {})
        // (if serviceAccount != null then { serviceAccount = serviceAccount; } else {})
        // (if role != null then { role = role; } else {})
        // (if roleBinding != null then { roleBinding = roleBinding; } else {})
        // (if statefulSet != null then { statefulSet = statefulSet; } else {})
        // (if pvc != null then { pvc = pvc; } else {})
        // (if secret != null then { secret = secret; } else {})
        // (if serviceMonitor != null then { serviceMonitor = serviceMonitor; } else {});
    in
    resourceSet;

in
{
  inherit mkDeployment mkService mkConfigMap mkIngress mkServiceAccount mkRole mkRoleBinding mkStatefulSet mkPVC mkSecret mkServiceMonitor mkResources;
}