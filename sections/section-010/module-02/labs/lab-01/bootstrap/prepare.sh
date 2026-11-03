#!/usr/bin/env bash
# Lab starting state: the default EventBus, the Secret dispatch-token, and an
# unprotected webhook EventSource "dispatch" with a Sensor that creates Workflows.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/dispatch.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/dispatch --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/dispatch --timeout=180s
