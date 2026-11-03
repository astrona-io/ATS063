#!/usr/bin/env bash
# Playground starting state: the default EventBus and the EventSource "telemetry" with three events.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/telemetry.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/telemetry --timeout=180s
