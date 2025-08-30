{ lib }:

let
  # Generate Chart.yaml metadata
  mkChartMetadata = config:
    let
      name = config.name or "unnamed-chart";
      version = config.version or "0.1.0";
      description = config.description or "${name} Helm chart";
      appVersion = config.appVersion or version;
      apiVersion = config.apiVersion or "v2";
      type = config.type or "application";
      keywords = config.keywords or [];
      home = config.home or "";
      sources = config.sources or [];
      maintainers = config.maintainers or [];
      dependencies = config.dependencies or [];
      annotations = config.annotations or {};
    in
    {
      apiVersion = apiVersion;
      name = name;
      description = description;
      type = type;
      version = version;
      appVersion = appVersion;
      keywords = keywords;
      home = home;
      sources = sources;
      maintainers = maintainers;
      dependencies = dependencies;
      annotations = annotations;
    };

  # Generate YAML output for the entire chart
  mkYamlOutput = chartMeta: resources:
    let
      # Convert chart metadata to YAML
      chartYaml = lib.generators.toYAML {} chartMeta;

      # Combine all resources into a single YAML stream
      resourceYamls = lib.concatStringsSep "\n---\n" (
        lib.mapAttrsToList (name: resource:
          lib.generators.toYAML {} resource
        ) resources
      );

      # Template files (if any)
      templatesDir = "# templates/\n";

      # Chart.yaml
      chartFile = "# Chart.yaml\n${chartYaml}\n";

      # values.yaml (empty for now, can be extended)
      valuesFile = "# values.yaml\n{}";

    in
    ''
      ${chartFile}
      ---
      ${valuesFile}
      ---
      ${templatesDir}
      ---
      ${resourceYamls}
    '';

in
{
  inherit mkChartMetadata mkYamlOutput;
}