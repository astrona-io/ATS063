#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

bound=0
for i in 0 1 2; do
  claim="eventbus-audit-js-vol-eventbus-audit-js-$i"
  phase=$(kubectl -n "$NS" get pvc "$claim" -o jsonpath='{.status.phase}' 2>/dev/null)
  size=$(kubectl -n "$NS" get pvc "$claim" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
  if [ "$phase" = "Bound" ] && [ "$size" = "1Gi" ]; then
    bound=$((bound + 1))
  else
    echo "FAIL: claim $claim is '${phase:-missing}' with size '${size:-none}', expected Bound and 1Gi"
    fail=1
  fi
done
[ "$bound" = "3" ] && echo "PASS: all three server pods have a Bound 1Gi claim"

vol=$(kubectl -n "$NS" get eventbus audit -o jsonpath='{.spec.jetstream.persistence.volumeSize}' 2>/dev/null)
if [ "$vol" = "1Gi" ]; then
  echo "PASS: spec.jetstream.persistence.volumeSize is 1Gi"
else
  echo "FAIL: spec.jetstream.persistence.volumeSize is '${vol}', expected 1Gi"
  fail=1
fi
exit $fail
