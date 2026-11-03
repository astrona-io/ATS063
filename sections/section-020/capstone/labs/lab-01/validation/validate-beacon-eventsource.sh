#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get eventsource beacon >/dev/null 2>&1; then
  echo "FAIL: EventSource beacon not found in $NS"
  exit 1
fi
bus=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.spec.eventBusName}' 2>/dev/null)
[ "$bus" = "signals" ] && pass "EventSource beacon uses the bus signals" || bad "EventSource beacon has eventBusName '${bus}', expected signals"

reps=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$reps" = "2" ] && pass "spec.replicas is 2" || bad "spec.replicas is '${reps}', expected 2"

ready=0
for _ in $(seq 1 30); do
  ready=$(kubectl -n "$NS" get pods -l eventsource-name=beacon -o jsonpath='{range .items[*]}{.status.phase}{" "}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}' 2>/dev/null | grep -c '^Running True')
  [ "$ready" = "2" ] && break
  sleep 4
done
[ "$ready" = "2" ] && pass "2 EventSource pods are Running and Ready" || bad "expected 2 ready EventSource pods, found $ready"

for ev in alert ack; do
  port=$(kubectl -n "$NS" get eventsource beacon -o jsonpath="{.spec.webhook.$ev.port}" 2>/dev/null)
  ep=$(kubectl -n "$NS" get eventsource beacon -o jsonpath="{.spec.webhook.$ev.endpoint}" 2>/dev/null)
  [ "$port" = "12000" ] && [ "$ep" = "/$ev" ] && pass "event $ev listens on port 12000 at /$ev" || bad "event $ev must listen on port 12000 at /$ev (got '$port' '$ep')"
done
exit $fail
