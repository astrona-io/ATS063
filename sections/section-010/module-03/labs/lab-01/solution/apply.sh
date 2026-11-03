#!/usr/bin/env bash
# Reference solution: run the trigger on either event and copy body.ship into the Workflow.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed sensor/launch --timeout=180s
# The controller replaces the Sensor pod after the change; wait until a single pod is ready.
for _ in $(seq 1 40); do
  n=$(kubectl -n starfleet get pods -l sensor-name=launch --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "1" ] && break
  sleep 3
done
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=launch --timeout=120s
