#!/usr/bin/env bash
# Starting state helper: the default EventBus, a Kafka broker and a RabbitMQ broker.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/kafka.yaml" -f "$DIR/manifests/rabbitmq.yaml"
kubectl -n starfleet wait --for=condition=Available deployment/kafka --timeout=300s
kubectl -n starfleet wait --for=condition=Ready pod/rabbitmq --timeout=300s
