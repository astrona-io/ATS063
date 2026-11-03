#!/usr/bin/env bash
# Starting state: the default EventBus, the beacon service and the EventSource gate.
# UNTESTED: written from the upstream manifests, not run yet.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/beacon.yaml" -f "$DIR/manifests/gate.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed eventsource/gate --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=gate --timeout=180s
# The flawed Sensor the learner has to repair.
kubectl apply -f "$DIR/manifests/relay.yaml"
kubectl -n starfleet wait --for=condition=Deployed sensor/relay --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=relay --timeout=180s
