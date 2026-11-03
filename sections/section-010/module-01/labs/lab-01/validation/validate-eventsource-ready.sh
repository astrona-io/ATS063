#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get eventsource webhook >/dev/null 2>&1; then
  echo "FAIL: EventSource webhook not found in $NS"
  exit 1
fi
pass "EventSource webhook exists"

endpoint=$(kubectl -n "$NS" get eventsource webhook -o jsonpath='{.spec.webhook.mission.endpoint}' 2>/dev/null)
method=$(kubectl -n "$NS" get eventsource webhook -o jsonpath='{.spec.webhook.mission.method}' 2>/dev/null)
port=$(kubectl -n "$NS" get eventsource webhook -o jsonpath='{.spec.webhook.mission.port}' 2>/dev/null)
[ "$endpoint" = "/mission" ] && pass "event mission listens on /mission" || bad "event mission must have endpoint /mission (got '$endpoint')"
[ "$method" = "POST" ] && pass "event mission accepts POST" || bad "event mission must have method POST (got '$method')"
[ "$port" = "12000" ] && pass "event mission uses port 12000" || bad "event mission must use port 12000 (got '$port')"

if kubectl -n "$NS" get service webhook-eventsource-svc >/dev/null 2>&1; then
  pass "Service webhook-eventsource-svc exists"
else
  bad "Service webhook-eventsource-svc is missing (set spec.service on the EventSource)"
fi

deployed=$(kubectl -n "$NS" get eventsource webhook -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource is deployed" || bad "EventSource condition Deployed is '$deployed', expected True"

exit $fail
