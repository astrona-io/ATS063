#!/usr/bin/env bash
# Lab starting state: the default EventBus, the EventSource "beacon" with two events and the Sensor "gatekeeper".
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/beacon.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/gatekeeper --timeout=180s
