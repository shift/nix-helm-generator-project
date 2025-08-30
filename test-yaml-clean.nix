let
  chart = import ./test-basic.nix;
in
{
  chartYaml = builtins.toFile "Chart.yaml" (builtins.toJSON chart.chartMeta);
  templates = builtins.toFile "templates.yaml" (builtins.concatStringsSep "\n---\n" [
    (builtins.toJSON chart.productionResources.deployment)
    (builtins.toJSON chart.productionResources.service)
  ]);
}