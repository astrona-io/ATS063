#!/usr/bin/env bash
# Reference solution: the repaired Sensor relay with header, policy, atLeastOnce, retryStrategy and dlqTrigger.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$DIR/solution.yaml"
kubectl -n starfleet wait --for=condition=Deployed sensor/relay --timeout=180s
kubectl -n starfleet rollout status deployment -l sensor-name=relay --timeout=180s
