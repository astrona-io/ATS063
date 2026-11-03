#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

replicas=$(kubectl -n "$NS" get sensor beacon -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$replicas" = "2" ]; then
  echo "PASS: spec.replicas of Sensor beacon is 2"
else
  echo "FAIL: spec.replicas of Sensor beacon is '${replicas:-unset}', expected 2"
  fail=1
fi

sa=$(kubectl -n "$NS" get sensor beacon -o jsonpath='{.spec.template.serviceAccountName}' 2>/dev/null)
if [ "$sa" = "event-trigger" ]; then
  echo "PASS: the Sensor still uses the service account event-trigger"
else
  echo "FAIL: spec.template.serviceAccountName of the Sensor is '${sa:-unset}', expected event-trigger"
  fail=1
fi

ready=0
for _ in $(seq 1 40); do
  ready=$(kubectl -n "$NS" get pods -l sensor-name=beacon --field-selector=status.phase=Running \
    -o custom-columns=NAME:.metadata.name,DEL:.metadata.deletionTimestamp,READY:.status.containerStatuses[0].ready --no-headers 2>/dev/null \
    | awk '$2=="<none>" && $3=="true" {n++} END {print n+0}')
  [ "$ready" = "2" ] && break
  sleep 3
done
if [ "$ready" = "2" ]; then
  echo "PASS: two Sensor pods are Running and Ready"
else
  echo "FAIL: found $ready ready Sensor pods, expected 2"
  fail=1
fi
exit $fail
