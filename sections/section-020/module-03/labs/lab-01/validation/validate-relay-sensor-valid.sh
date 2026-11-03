#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

cond() { kubectl -n "$NS" get sensor relay -o jsonpath="{.status.conditions[?(@.type==\"$1\")].status}" 2>/dev/null; }

if ! kubectl -n "$NS" get sensor relay >/dev/null 2>&1; then
  echo "FAIL: Sensor relay does not exist in $NS"
  exit 1
fi

if [ "$(cond Deployed)" = "True" ] && [ "$(cond TriggersProvided)" = "True" ]; then
  echo "PASS: Sensor relay is deployed and its triggers are valid"
else
  msg=$(kubectl -n "$NS" get sensor relay -o jsonpath='{.status.conditions[?(@.type=="TriggersProvided")].message}' 2>/dev/null)
  echo "FAIL: Sensor relay is not deployed or its triggers are invalid: ${msg:-no message}"
  fail=1
fi

deps=$(kubectl -n "$NS" get sensor relay -o jsonpath='{range .spec.dependencies[*]}{.name}/{.eventSourceName}/{.eventName}{"\n"}{end}' 2>/dev/null)
if [ "$deps" = "gate/gate/relay" ]; then
  echo "PASS: the dependency gate on the event relay of EventSource gate is kept"
else
  echo "FAIL: the Sensor must have exactly one dependency named gate on EventSource gate, event relay (found: ${deps:-none})"
  fail=1
fi

triggers=$(kubectl -n "$NS" get sensor relay -o jsonpath='{range .spec.triggers[*]}{.template.name}{"\n"}{end}' 2>/dev/null)
if [ "$triggers" = "notify-beacon" ]; then
  echo "PASS: the trigger notify-beacon is kept as the only top-level trigger"
else
  echo "FAIL: the Sensor must have exactly one top-level trigger named notify-beacon (found: ${triggers:-none})"
  fail=1
fi

hook=$(kubectl -n "$NS" get configmap beacon-cgi -o jsonpath='{.data.hook}' 2>/dev/null)
if printf '%s' "$hook" | grep -q 'HTTP_X_FLEET_TOKEN' && printf '%s' "$hook" | grep -q -- '-lt 3'; then
  echo "PASS: the beacon service logic is unchanged"
else
  echo "FAIL: the ConfigMap beacon-cgi was changed. Fix the Sensor, not the service"
  fail=1
fi
exit $fail
