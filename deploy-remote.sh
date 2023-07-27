#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "kubectl" "helm" "linkerd"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

DOMAIN=remote.cluster.local
CERT_ISSUER_ID=issuer-remote

kubectl config use-context kind-lgtm-remote

echo "Deploying Prometheus CRDs"
. deploy-prometheus-crds.sh

#echo "Deploying Linkerd"
#. deploy-linkerd.sh

# Not needed in our case, but if we expose headless services associated with StatefulSets we should add:
# --set "enableHeadlessServices=true"
echo "Creating link from the remote cluster into the central cluster"
linkerd mc link --context kind-lgtm-central --cluster-name lgtm-central | kubectl apply -f -

echo "Setting up namespaces"
for ns in observability tns mimir tempo loki; do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $ns
  annotations:
    linkerd.io/inject: enabled
EOF
done

echo "Deploying Prometheus (for Metrics)"
helm upgrade --install monitor prometheus-community/kube-prometheus-stack \
  -n observability -f values-prometheus-common.yaml -f values-prometheus-remote.yaml --wait

echo "Deploying Grafana Promtail (for Logs)"
helm upgrade --install promtail grafana/promtail \
  -n observability -f values-promtail-common.yaml -f values-promtail-remote.yaml --wait

#echo "Deplying Grafana Agent (for Traces)"
#kubectl apply -f remote-agent-config-remote.yaml
#kubectl apply -f remote-agent.yaml

#echo "Deploying TNS application"
#kubectl apply -f remote-apps.yaml
