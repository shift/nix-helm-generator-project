{ lib, chart, resources, production, validation, mkChart }:

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

  # Simple dependency resolution
  resolveDependencies = charts: dependencies:
    let
      chartNames = lib.attrNames charts;

      # Validate that all dependencies reference existing charts
      validateDeps = deps:
        lib.map (dep:
          if lib.elem dep.name chartNames
          then dep
          else throw "Dependency '${dep.name}' references non-existent chart. Available charts: ${lib.concatStringsSep ", " chartNames}"
        ) deps;

      validatedDeps = validateDeps dependencies;

      # For now, return charts in the order they appear in dependencies
      # followed by any remaining charts
      depOrder = lib.map (dep: dep.name) validatedDeps;
      remainingCharts = lib.filter (name: !lib.elem name depOrder) chartNames;
    in depOrder ++ remainingCharts;

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

      # Resolve dependencies
      orderedCharts = resolveDependencies validatedConfig.charts validatedConfig.dependencies;

      # Generate individual charts
      generatedCharts = generateCharts validatedConfig orderedCharts;

      # Combine outputs
      combinedYaml = combineOutputs generatedCharts;

    in
    {
      inherit validatedConfig orderedCharts generatedCharts combinedYaml;

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