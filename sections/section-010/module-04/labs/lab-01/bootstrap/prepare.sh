#!/usr/bin/env bash
# Lab starting state: the default EventBus, a NATS server with a client pod,
# and the NATS EventSource "radio" with a Sensor that creates Workflows.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/nats.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/nats --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/natsbox --timeout=180s
kubectl apply -f "$DIR/manifests/radio.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/radio --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/radio --timeout=180s
