{ lib }:

let
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
    in
    {
      apiVersion = "apps/v1";
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
    in
    if !enabled then null else {
      apiVersion = "networking.k8s.io/v1";
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

  # Main function to generate all resources
  mkResources = config:
    let
      appConfig = config.app or {};
      deployment = mkDeployment config appConfig;
      service = mkService config appConfig;
      configMap = mkConfigMap config appConfig;
      ingress = mkIngress config appConfig;

      # Filter out null resources
      allResources = lib.filter (r: r != null) [deployment service configMap ingress];

      # Create a named set of resources
      resourceSet = {
        deployment = deployment;
        service = service;
      } // (if configMap != null then { configMap = configMap; } else {})
        // (if ingress != null then { ingress = ingress; } else {});
    in
    resourceSet;

in
{
  inherit mkDeployment mkService mkConfigMap mkIngress mkResources;
}