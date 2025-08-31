#!/usr/bin/env groovy

class NixHelmLib implements Serializable {
    def script

    NixHelmLib(script) {
        this.script = script
    }

    def setupNix() {
        script.sh '''
            if ! command -v nix &> /dev/null; then
                curl -L https://nixos.org/nix/install | sh
                . ~/.nix-profile/etc/profile.d/nix.sh
            fi
        '''
    }

    def generateCharts(appName = 'my-app') {
        script.sh "nix develop -c -- nix eval --json .#${appName} > charts.json"
        script.archiveArtifacts artifacts: 'charts.json', fingerprint: true
    }

    def validateCharts() {
        script.sh 'nix develop -c -- nix run .#validate-charts'
    }

    def deployToEnvironment(env, cluster) {
        script.sh """
            kubectl config use-context ${cluster}
            kubectl apply -f charts.json
            kubectl rollout status deployment/my-app -n ${env}
        """
    }

    def cleanup() {
        script.sh 'rm -f charts.json'
    }
}