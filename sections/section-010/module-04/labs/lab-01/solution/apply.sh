#!/usr/bin/env bash
# Reference solution: correct the subject and set jsonBody on the NATS event.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/radio --timeout=180s
# The controller replaces the pod after the change; wait until a single pod is ready.
for _ in $(seq 1 40); do
  n=$(kubectl -n starfleet get pods -l eventsource-name=radio --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "1" ] && break
  sleep 3
done
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=radio --timeout=120s
