{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  values = builtins.fromJSON (builtins.readFile ./chart.values.json);

  # Example transformation: rename top-level keys or apply simple mappings.
  migrate = v: lib.recursiveUpdate v {
    # Add any repo-specific renames or defaults here.
    # example: rename `oldName` -> `newName` if present
  };

in
{
  chart = {
    name = "example-chart";
    source = ./chart; # local chart path or URI
    version = "0.0.0";
    values = migrate values;
  };
}
