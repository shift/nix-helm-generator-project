let
  lib = import <nixpkgs> {}.lib;
  validation = import ./lib/validation.nix { inherit lib; };
  config = {
    name = "";
    version = "1.0.0";
    description = "Debug chart";
  };
in
let
  hasName = config ? name;
  hasVersion = config ? version;
  nameValid = hasName && config.name != "" && lib.stringLength config.name <= 63;
  versionValid = hasVersion && config.version != "" && lib.match "[0-9]+\\.[0-9]+\\.[0-9]+" config.version != null;
in
{
  hasName = hasName;
  hasVersion = hasVersion;
  nameValid = nameValid;
  versionValid = versionValid;
  configName = config.name;
  configVersion = config.version;
}