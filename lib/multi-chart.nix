{ lib, chart, resources, production, validation, mkChart, shared, dependency }:

let
  # Multi-chart configuration validation
  validateMultiChartConfig = config:
    let
      requiredFields = ["name" "charts"];
      missingFields = lib.filter (field: !config ? ${field}) requiredFields;

      # Validate chart configurations
      validateCharts = charts:
        lib.mapAttrs (name: chartConfig:
          if chartConfig ? name && chartConfig ? version
          then chartConfig
          else throw "Chart '${name}' missing required fields: name, version"
        ) charts;

      # Validate dependencies
      validateDependencies = deps:
        if deps == null then []
        else lib.map (dep:
          if dep ? name
          then dep
          else throw "Dependency missing required field: name"
        ) deps;

    in
    if missingFields != []
    then throw "Multi-chart configuration missing required fields: ${lib.concatStringsSep ", " missingFields}"
    else {
      name = config.name;
      version = config.version or "1.0.0";
      description = config.description or "${config.name} multi-chart application";
      charts = validateCharts config.charts;
      dependencies = validateDependencies (config.dependencies or []);
      global = config.global or {};
    };

  # Enhanced dependency resolution with condition evaluation
  resolveDependencies = charts: dependencies: config:
    let
      # Create values object for condition evaluation
      values = lib.mapAttrs (chartName: chartConfig:
        let
          enabled = if chartConfig ? enabled then chartConfig.enabled else true;
        in { inherit enabled; } // chartConfig
      ) charts;

      # Use the enhanced dependency resolution
      resolved = dependency.resolveAllDependencies charts dependencies values;
    in resolved.sorted;

  # Generate individual charts with shared context
  generateCharts = multiConfig: orderedCharts:
    let
      # Merge global config with chart-specific config
      mergeConfigs = chartName: chartConfig:
        let
          globalConfig = multiConfig.global;
          merged = lib.recursiveUpdate globalConfig chartConfig;
        in merged // {
          # Ensure chart has its own name and version
          name = chartConfig.name or chartName;
          version = chartConfig.version or multiConfig.version;
        };

      # Generate each chart
      generateChart = chartName:
        let
          chartConfig = multiConfig.charts.${chartName};
          mergedConfig = mergeConfigs chartName chartConfig;
          generated = mkChart mergedConfig;
        in {
          name = chartName;
          config = mergedConfig;
          chart = generated;
        };

    in
    lib.map generateChart orderedCharts;

  # Combine all chart outputs into unified YAML
  combineOutputs = generatedCharts:
    let
      # Generate multi-chart metadata
      multiMeta = {
        apiVersion = "v2";
        name = "multi-chart";
        description = "Multi-chart application bundle";
        type = "application";
        version = "1.0.0";
      };

      # Combine all chart YAMLs
      allYamls = lib.concatStringsSep "\n---\n" (
        [ (lib.generators.toYAML {} multiMeta) ] ++
        lib.map (genChart: genChart.chart.yamlOutput) generatedCharts
      );

    in allYamls;

  # Main multi-chart generation function
  mkMultiChart = config:
    let
      # Validate configuration
      validatedConfig = validateMultiChartConfig config;

      # Process shared resources if present
      sharedResources = if config ? shared
        then shared.mkSharedResources config.shared
        else [];

      # Merge shared resources into chart configurations
      chartsWithShared = if config ? shared
        then shared.mergeSharedIntoCharts sharedResources validatedConfig.charts
        else validatedConfig.charts;

      # Resolve dependencies with proper condition evaluation
      orderedCharts = resolveDependencies chartsWithShared validatedConfig.dependencies validatedConfig;

      # Generate individual charts
      generatedCharts = generateCharts validatedConfig orderedCharts;

      # Generate shared resources YAML
      sharedYaml = if sharedResources != []
        then lib.concatStringsSep "\n---\n" (lib.map (res: lib.generators.toYAML {} res) sharedResources)
        else "";

      # Combine outputs
      combinedYaml = if sharedYaml != ""
        then sharedYaml + "\n---\n" + combineOutputs generatedCharts
        else combineOutputs generatedCharts;

    in
    {
      inherit validatedConfig orderedCharts generatedCharts combinedYaml sharedResources;

      # Convenience functions
      toString = combinedYaml;
      toFile = name: lib.writeText name combinedYaml;

      # Individual chart access
      charts = lib.listToAttrs (
        lib.map (genChart: {
          name = genChart.name;
          value = genChart.chart;
        }) generatedCharts
      );
    };

in
{
  inherit mkMultiChart validateMultiChartConfig resolveDependencies;
}