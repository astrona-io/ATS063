#!/usr/bin/env bash
# Lab starting state: the default EventBus, then the broken beacon EventSource and Sensor.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/beacon.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/beacon --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=beacon --timeout=180s
