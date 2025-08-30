{ lib, ... }:

let
  # Import the Nix Helm Generator module
  nixHelm = import ../lib {};

  # Cert-manager configuration
  certManagerConfig = {
    name = "cert-manager";
    version = "1.0.0";
    description = "A Helm chart for cert-manager certificate management";
    appVersion = "v1.13.0";

    app = {
      image = "cert-manager/cert-manager-controller:v1.13.0";
      ports = [9402];

      # Environment variables
      env = {
        POD_NAMESPACE = "cert-manager";
      };

      # Configuration data
      configData = {
        "cluster-issuer-letsencrypt-staging.yaml" = ''
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: letsencrypt-staging
          spec:
            acme:
              server: https://acme-staging-v02.api.letsencrypt.org/directory
              email: admin@example.com
              privateKeySecretRef:
                name: letsencrypt-staging
              solvers:
              - http01:
                  ingress:
                    class: nginx
        '';

        "cluster-issuer-letsencrypt-prod.yaml" = ''
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: letsencrypt-prod
          spec:
            acme:
              server: https://acme-v02.api.letsencrypt.org/directory
              email: admin@example.com
              privateKeySecretRef:
                name: letsencrypt-prod
              solvers:
              - http01:
                  ingress:
                    class: nginx
        '';

        "certificate-example.yaml" = ''
          apiVersion: cert-manager.io/v1
          kind: Certificate
          metadata:
            name: example-tls
            namespace: default
          spec:
            secretName: example-tls
            issuerRef:
              name: letsencrypt-prod
              kind: ClusterIssuer
            dnsNames:
            - example.com
            - www.example.com
        '';
      };

      # Production configuration
      production = {
        # Resource limits and requests
        resources = {
          requests = {
            cpu = "100m";
            memory = "128Mi";
          };
          limits = {
            cpu = "500m";
            memory = "512Mi";
          };
        };

        # Health checks
        healthChecks = {
          readinessProbe = {
            httpGet = {
              path = "/healthz";
              port = 9402;
            };
            initialDelaySeconds = 5;
            periodSeconds = 10;
          };
          livenessProbe = {
            httpGet = {
              path = "/healthz";
              port = 9402;
            };
            initialDelaySeconds = 30;
            periodSeconds = 30;
          };
        };

        # Security context
        securityContext = {
          pod = {
            runAsUser = 65534;
            runAsGroup = 65534;
            fsGroup = 65534;
          };
          container = {
            allowPrivilegeEscalation = false;
            readOnlyRootFilesystem = true;
            runAsNonRoot = true;
            runAsUser = 65534;
          };
        };

        # Pod Disruption Budget
        pdb = {
          enabled = true;
          minAvailable = "50%";
        };

        # Network Policy
        networkPolicy = {
          enabled = true;
          ingress = [
            {
              from = [
                {
                  namespaceSelector = {
                    matchLabels = {
                      name = "ingress-nginx";
                    };
                  };
                }
                {
                  podSelector = {
                    matchLabels = {
                      app = "webhook";
                    };
                  };
                }
              ];
              ports = [
                {
                  port = 9402;
                  protocol = "TCP";
                }
              ];
            }
          ];
        };
      };
    };

    # Chart metadata
    keywords = ["cert-manager" "certificate" "tls" "letsencrypt" "kubernetes"];
    home = "https://cert-manager.io";
    sources = ["https://github.com/cert-manager/cert-manager"];
    maintainers = [
      {
        name = "The cert-manager Authors";
        email = "cert-manager-maintainers@googlegroups.com";
      }
    ];
  };

in
# Generate the chart using the Nix Helm Generator
nixHelm.mkChart certManagerConfig