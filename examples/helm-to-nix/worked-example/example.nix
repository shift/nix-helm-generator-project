{ pkgs ? import <nixpkgs> {} }:
let
  vals = builtins.fromJSON (builtins.readFile ./values.json);
in
  {
    name = "demo-nix";
    replicas = vals.replicaCount;
    image = vals.image;
    service = vals.service;
  }
