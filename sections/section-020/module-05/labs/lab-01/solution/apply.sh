#!/usr/bin/env bash
# Reference solution: use the existing bus, match the event name, give the Sensor an identity.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed eventsource/fleet --timeout=180s
for _ in $(seq 1 40); do
  n=$(kubectl -n starfleet get pods -l sensor-name=fleet --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "1" ] && break
  sleep 3
done
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=fleet --timeout=180s
