{ pkgs ? import <nixpkgs> {} }:

let
  helm = pkgs.kubernetes-helm;
  yq = pkgs.yq;
  chartDir = ./.;
  out = pkgs.runCommand "render-demo" { buildInputs = [ helm yq ]; } ''
    mkdir -p $out
    # render values and templates
    ${helm}/bin/helm show values ${chartDir} > $out/values.yaml
    ${helm}/bin/helm template ${chartDir} > $out/rendered.yaml
    # convert values to json
    ${yq}/bin/yq -o=json '.' $out/values.yaml > $out/values.json
  '';
in
  {
    chart = chartDir;
    outputs = { inherit out; };
  }
