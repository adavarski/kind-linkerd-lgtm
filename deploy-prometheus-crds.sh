#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

type kubectl >/dev/null 2>&1 || { echo >&2 "kubectl required but it's not installed; aborting."; exit 1; }

BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.66.0/example/prometheus-operator-crd/monitoring.coreos.com_"

for YAML in \
  alertmanagerconfigs.yaml \
  alertmanagers.yaml \
  podmonitors.yaml \
  probes.yaml \
  prometheuses.yaml \
  prometheusrules.yaml \
  servicemonitors.yaml \
  thanosrulers.yaml; do

  kubectl apply --server-side -f ${BASE}${YAML}
done
