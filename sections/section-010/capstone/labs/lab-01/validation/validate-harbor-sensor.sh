#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get sensor logbook >/dev/null 2>&1; then
  echo "FAIL: Sensor logbook not found in $NS"
  exit 1
fi
pairs=$(kubectl -n "$NS" get sensor logbook -o jsonpath='{range .spec.dependencies[*]}{.eventSourceName}{"/"}{.eventName}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
[ "$pairs" = "harbor/arrival harbor/departure " ] && pass "Sensor logbook depends on the events arrival and departure of harbor" || bad "Sensor logbook must depend on harbor/arrival and harbor/departure (got: $pairs)"

cond=$(kubectl -n "$NS" get sensor logbook -o jsonpath='{.spec.triggers[0].template.conditions}' 2>/dev/null)
if [ -n "$cond" ] && printf '%s' "$cond" | grep -q '||' && ! printf '%s' "$cond" | grep -q '&&'; then
  pass "the trigger has an or condition: $cond"
else
  bad "the trigger must have conditions that join the two dependency names with || (got '$cond')"
fi
sa=$(kubectl -n "$NS" get sensor logbook -o jsonpath='{.spec.template.serviceAccountName}' 2>/dev/null)
[ "$sa" = "event-trigger" ] && pass "the Sensor uses the service account event-trigger" || bad "the Sensor must use the service account event-trigger (got '$sa')"
deployed=$(kubectl -n "$NS" get sensor logbook -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "Sensor logbook is Deployed" || bad "Sensor logbook is not Deployed (status '${deployed}')"
exit $fail
