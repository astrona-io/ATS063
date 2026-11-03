#!/usr/bin/env bash
# Starting state helper: the default EventBus and a NATS server with a client pod.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/manifests/eventbus.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl apply -f "$DIR/manifests/nats.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/nats --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/natsbox --timeout=180s
