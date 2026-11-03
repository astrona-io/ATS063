#!/usr/bin/env bash
# Lab starting state: the default EventBus and a webhook EventSource with a Sensor
# that has three faults (bus name, event name, service account).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/relay.yaml"
kubectl -n starfleet wait --for=condition=Deployed sensor/fleet --timeout=180s
