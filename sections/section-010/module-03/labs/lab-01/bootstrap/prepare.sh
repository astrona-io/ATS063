#!/usr/bin/env bash
# Lab starting state: the default EventBus, the EventSource "fleet" with two events and the Sensor "launch".
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/fleet.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/launch --timeout=180s
