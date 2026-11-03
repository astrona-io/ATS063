#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

for kind in eventsource sensor; do
  name=ledger
  if ! kubectl -n "$NS" get "$kind" "$name" >/dev/null 2>&1; then
    echo "FAIL: the $kind $name does not exist in $NS"
    fail=1
    continue
  fi
  bus=$(kubectl -n "$NS" get "$kind" "$name" -o jsonpath='{.spec.eventBusName}' 2>/dev/null)
  if [ "$bus" = "audit" ]; then
    echo "PASS: the $kind $name uses eventBusName audit"
  else
    echo "FAIL: the $kind $name has eventBusName '${bus}', expected audit"
    fail=1
  fi
  deployed=$(kubectl -n "$NS" get "$kind" "$name" -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
  if [ "$deployed" = "True" ]; then
    echo "PASS: the $kind $name is Deployed"
  else
    echo "FAIL: the $kind $name is not Deployed (condition status: '${deployed}')"
    fail=1
  fi
done

# The default bus must not be needed: no bus named default may exist as a workaround.
if kubectl -n "$NS" get eventbus default >/dev/null 2>&1; then
  echo "FAIL: an EventBus named default exists; the task is to use the bus audit instead"
  fail=1
else
  echo "PASS: no EventBus named default exists"
fi
exit $fail
