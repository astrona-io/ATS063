#!/usr/bin/env bash
# Reference solution: a dedicated EventBus named audit, and an EventSource and a Sensor that use it.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/audit --timeout=300s
kubectl -n starfleet wait --for=condition=Deployed eventsource/ledger --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/ledger --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=ledger --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=ledger --timeout=180s
