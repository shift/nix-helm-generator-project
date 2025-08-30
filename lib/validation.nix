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

in
{
  inherit validateChartConfig;
}