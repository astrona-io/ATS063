#!/usr/bin/env bash
# Reference solution: protect the order event, add the calendar EventSource and its Sensor.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/dispatch --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed eventsource/ticker --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/ticker --timeout=180s
# The controller replaces the dispatch pod after the change; wait until a single pod is ready.
for _ in $(seq 1 40); do
  n=$(kubectl -n starfleet get pods -l eventsource-name=dispatch --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "1" ] && break
  sleep 3
done
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=dispatch --timeout=120s
