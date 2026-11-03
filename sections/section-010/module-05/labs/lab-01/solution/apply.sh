#!/usr/bin/env bash
# Reference solution: correct the port and the topic, and set jsonBody on the Kafka event.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/dock --timeout=180s
for _ in $(seq 1 40); do
  n=$(kubectl -n starfleet get pods -l eventsource-name=dock --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "1" ] && break
  sleep 3
done
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=dock --timeout=120s
