let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  validation = import ./lib/validation.nix { inherit lib; };
  config = {
    name = "";
    version = "1.0.0";
    description = "Test chart";
  };
in
validation.validateChartConfig config