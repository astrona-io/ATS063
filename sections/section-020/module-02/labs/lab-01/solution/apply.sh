#!/usr/bin/env bash
# Reference solution: the corrected Sensor gatekeeper.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed sensor/gatekeeper --timeout=180s
# The controller replaces the Sensor pod after a dependency change. Wait until exactly one pod is ready.
for _ in $(seq 1 60); do
  total=$(kubectl -n starfleet get pods -l sensor-name=gatekeeper -o name 2>/dev/null | wc -l | tr -d ' ')
  ready=$(kubectl -n starfleet get pods -l sensor-name=gatekeeper -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c True || true)
  if [ "$total" = "1" ] && [ "$ready" = "1" ]; then break; fi
  sleep 3
done
sleep 10
