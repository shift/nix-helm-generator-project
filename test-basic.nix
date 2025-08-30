let
  nix-helm-generator = import ./lib {};
in
nix-helm-generator.mkChart {
  name = "test-app";
  version = "1.0.0";
  description = "Test application";

  app = {
    image = "nginx:alpine";
    replicas = 2;
    ports = [80 443];
    env = {
      APP_ENV = "test";
      DEBUG = "true";
    };
  };
}