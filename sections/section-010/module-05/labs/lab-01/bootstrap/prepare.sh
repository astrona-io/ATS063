#!/usr/bin/env bash
# Lab starting state: the default EventBus, a Kafka broker, and the Kafka EventSource "dock"
# with a Sensor. The EventSource has three faults (port, topic, jsonBody).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/kafka.yaml"
kubectl -n starfleet wait --for=condition=Available deployment/kafka --timeout=300s
kubectl apply -f "$DIR/manifests/dock.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/dock --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/dock --timeout=180s
