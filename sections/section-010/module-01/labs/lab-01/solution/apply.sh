#!/usr/bin/env bash
# Reference solution: creates the EventSource and the Sensor and waits for both.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/webhook --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/mission --timeout=180s
