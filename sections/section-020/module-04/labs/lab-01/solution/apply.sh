#!/usr/bin/env bash
# Reference solution: a dedicated service account with a Lease Role for the EventSource,
# resources on both objects, and two Sensor replicas.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/beacon --timeout=180s
for label in eventsource-name sensor-name; do
  deploy=""
  for _ in $(seq 1 30); do
    deploy=$(kubectl -n starfleet get deployment -l "$label=beacon" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    [ -n "$deploy" ] && break
    sleep 2
  done
  kubectl -n starfleet rollout status "deployment/$deploy" --timeout=180s
done
