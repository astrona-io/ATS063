#!/usr/bin/env bash
# Lab starting state: ingress-nginx, the default EventBus, the webhook EventSource "gate" with a Sensor,
# and an Ingress with three faults (Service name, port, path).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/ingress-install.sh"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/gate.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/gate --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/gate --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=gate --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=gate --timeout=180s
for _ in $(seq 1 30); do
  kubectl apply -f "$DIR/manifests/gate-ingress.yaml" && break
  sleep 5
done
