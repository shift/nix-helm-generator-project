{ lib }:

let
  # Validate chart configuration
  validateChartConfig = config:
    let
      # Required fields
      requiredFields = ["name" "version"];

      # Check if all required fields are present
      hasName = config ? name;
      hasVersion = config ? version;
      missingFields = lib.optional (!hasName) "name" ++ lib.optional (!hasVersion) "version";

      # Basic validation rules
      nameValid = hasName && config.name != "" && lib.stringLength config.name <= 63;
      versionValid = hasVersion && config.version != "" && lib.match "[0-9]+\\.[0-9]+\\.[0-9]+" config.version != null;

      # App validation if present
      appValid = if config ? app then
        let
          app = config.app;
        in
        app ? image && app.image != ""
      else true;

      # Collect validation errors
      errors = []
        ++ (if missingFields != [] then ["Missing required fields: ${lib.concatStringsSep ", " missingFields}"] else [])
        ++ (if hasName && !nameValid then ["Invalid chart name: must be non-empty and <= 63 characters"] else [])
        ++ (if hasVersion && !versionValid then ["Invalid version format: must be semantic version (x.y.z)"] else [])
        ++ (if !appValid then ["Invalid app configuration: image is required"] else []);

    in
    if errors != [] then
      throw "Chart validation failed:\n${lib.concatStringsSep "\n" errors}"
    else
      config;

  # Validate app configuration
  validateAppConfig = appConfig:
    let
      # Validate image
      imageValid = appConfig ? image && lib.isString appConfig.image && appConfig.image != "";

      # Validate ports
      portsValid = if appConfig ? ports
        then lib.isList appConfig.ports && lib.all lib.isInt appConfig.ports
        else true;

      # Validate replicas
      replicasValid = if appConfig ? replicas
        then lib.isInt appConfig.replicas && appConfig.replicas > 0
        else true;

      # Validate environment variables
      envValid = if appConfig ? env
        then lib.isAttrs appConfig.env && lib.all lib.isString (lib.attrValues appConfig.env)
        else true;

      # Validate production config if present
      productionValid = if appConfig ? production
        then validateProductionConfig appConfig.production
        else { valid = true; errors = []; };

      # Collect errors
      errors = []
        ++ (if !imageValid then ["Invalid or missing image: must be a non-empty string"] else [])
        ++ (if !portsValid then ["Invalid ports: must be a list of integers"] else [])
        ++ (if !replicasValid then ["Invalid replicas: must be a positive integer"] else [])
        ++ (if !envValid then ["Invalid env: must be an attribute set of strings"] else [])
        ++ (if !productionValid.valid then productionValid.errors else []);

    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate production configuration
  validateProductionConfig = prodConfig:
    let
      # Validate PDB config
      pdbValid = if prodConfig ? pdb
        then validatePDBConfig prodConfig.pdb
        else { valid = true; errors = []; };

      # Validate resources config
      resourcesValid = if prodConfig ? resources
        then validateResourcesConfig prodConfig.resources
        else { valid = true; errors = []; };

      # Validate health checks
      healthChecksValid = if prodConfig ? healthChecks
        then validateHealthChecksConfig prodConfig.healthChecks
        else { valid = true; errors = []; };

      # Validate security context
      securityValid = if prodConfig ? securityContext
        then validateSecurityContextConfig prodConfig.securityContext
        else { valid = true; errors = []; };

      # Validate network policy
      networkValid = if prodConfig ? networkPolicy
        then validateNetworkPolicyConfig prodConfig.networkPolicy
        else { valid = true; errors = []; };

      # Collect errors
      errors = []
        ++ (if !pdbValid.valid then lib.map (e: "PDB: ${e}") pdbValid.errors else [])
        ++ (if !resourcesValid.valid then lib.map (e: "Resources: ${e}") resourcesValid.errors else [])
        ++ (if !healthChecksValid.valid then lib.map (e: "HealthChecks: ${e}") healthChecksValid.errors else [])
        ++ (if !securityValid.valid then lib.map (e: "SecurityContext: ${e}") securityValid.errors else [])
        ++ (if !networkValid.valid then lib.map (e: "NetworkPolicy: ${e}") networkValid.errors else []);

    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate PDB configuration
  validatePDBConfig = pdbConfig:
    let
      enabled = pdbConfig.enabled or false;
      errors = []
        ++ (if enabled && pdbConfig ? minAvailable && pdbConfig ? maxUnavailable
            then ["Cannot specify both minAvailable and maxUnavailable"] else [])
        ++ (if enabled && pdbConfig ? minAvailable && !lib.isString pdbConfig.minAvailable && !lib.isInt pdbConfig.minAvailable
            then ["minAvailable must be a string (percentage) or integer"] else [])
        ++ (if enabled && pdbConfig ? maxUnavailable && !lib.isString pdbConfig.maxUnavailable && !lib.isInt pdbConfig.maxUnavailable
            then ["maxUnavailable must be a string (percentage) or integer"] else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate resources configuration
  validateResourcesConfig = resourcesConfig:
    let
      # Validate requests
      requestsValid = if resourcesConfig ? requests
        then lib.isAttrs resourcesConfig.requests
        else true;

      # Validate limits
      limitsValid = if resourcesConfig ? limits
        then lib.isAttrs resourcesConfig.limits
        else true;

      errors = []
        ++ (if !requestsValid then ["requests must be an attribute set"] else [])
        ++ (if !limitsValid then ["limits must be an attribute set"] else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate health checks configuration
  validateHealthChecksConfig = hcConfig:
    let
      # Validate readiness probe
      readinessValid = if hcConfig ? readinessProbe
        then validateProbeConfig hcConfig.readinessProbe
        else { valid = true; errors = []; };

      # Validate liveness probe
      livenessValid = if hcConfig ? livenessProbe
        then validateProbeConfig hcConfig.livenessProbe
        else { valid = true; errors = []; };

      errors = []
        ++ (if !readinessValid.valid then lib.map (e: "readinessProbe: ${e}") readinessValid.errors else [])
        ++ (if !livenessValid.valid then lib.map (e: "livenessProbe: ${e}") livenessValid.errors else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate probe configuration
  validateProbeConfig = probeConfig:
    let
      hasValidProbe = probeConfig ? httpGet || probeConfig ? tcpSocket || probeConfig ? exec;
      errors = []
        ++ (if !hasValidProbe then ["Probe must have httpGet, tcpSocket, or exec"] else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate security context configuration
  validateSecurityContextConfig = secConfig:
    let
      # Validate pod security context
      podValid = if secConfig ? pod
        then lib.isAttrs secConfig.pod
        else true;

      # Validate container security context
      containerValid = if secConfig ? container
        then lib.isAttrs secConfig.container
        else true;

      errors = []
        ++ (if !podValid then ["pod security context must be an attribute set"] else [])
        ++ (if !containerValid then ["container security context must be an attribute set"] else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

  # Validate network policy configuration
  validateNetworkPolicyConfig = networkConfig:
    let
      enabled = networkConfig.enabled or false;
      errors = []
        ++ (if enabled && networkConfig ? ingress && !lib.isList networkConfig.ingress
            then ["ingress must be a list"] else [])
        ++ (if enabled && networkConfig ? egress && !lib.isList networkConfig.egress
            then ["egress must be a list"] else []);
    in
    {
      valid = errors == [];
      errors = errors;
    };

in
{
  inherit validateChartConfig validateAppConfig validateProductionConfig;
}