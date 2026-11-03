#!/usr/bin/env bash
# Starting state helper: the default EventBus and a Prometheus server that scrapes the Argo Events controller.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/prometheus.yaml"
kubectl -n starfleet wait --for=condition=Available deployment/prometheus --timeout=300s
