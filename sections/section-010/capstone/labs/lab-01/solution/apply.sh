#!/usr/bin/env bash
# Reference solution: a token-protected webhook EventSource and a Sensor that records each movement.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/harbor --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/logbook --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=harbor --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=logbook --timeout=180s
