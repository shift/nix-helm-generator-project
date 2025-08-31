# Simple Multi-Chart Example
# Demonstrates basic multi-chart functionality with two services

let
  nix-helm = import ../lib { };

  # API service chart
  apiChart = {
    name = "api-service";
    version = "1.0.0";

    app = {
      name = "api";
      image = "nginx:alpine";
      ports = [80];
    };

    resources = {
      deployment = {
        replicas = 2;
      };
      service = {
        type = "ClusterIP";
        ports = [{ port = 80; targetPort = 80; }];
      };
    };
  };

  # Web service chart
  webChart = {
    name = "web-service";
    version = "1.0.0";

    app = {
      name = "web";
      image = "nginx:alpine";
      ports = [80];
    };

    resources = {
      deployment = {
        replicas = 1;
      };
      service = {
        type = "LoadBalancer";
        ports = [{ port = 80; targetPort = 80; }];
      };
    };
  };

in
{
  name = "simple-app";
  version = "1.0.0";
  description = "Simple multi-chart application";

  charts = {
    inherit apiChart webChart;
  };

  dependencies = [
    { name = "apiChart"; }
    { name = "webChart"; }
  ];

  global = {
    namespace = "default";
  };
}