#!/usr/bin/env bash
# Reference solution: bus signals, EventSource beacon with two pods, Sensor escalate with a filter and two triggers.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/signals --timeout=300s
kubectl -n starfleet wait --for=condition=Deployed eventsource/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/escalate --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=escalate --timeout=180s
