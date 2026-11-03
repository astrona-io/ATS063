#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

bus=$(kubectl -n "$NS" get eventsource fleet -o jsonpath='{.spec.eventBusName}' 2>/dev/null)
if [ -z "$bus" ] || [ "$bus" = "default" ]; then
  pass "EventSource fleet uses the EventBus default"
else
  bad "EventSource fleet uses the EventBus '$bus', which does not exist"
fi

deployed=$(kubectl -n "$NS" get eventsource fleet -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource fleet is deployed" || bad "EventSource fleet condition Deployed is '$deployed', expected True"

ready=""
for _ in $(seq 1 20); do
  ready=$(kubectl -n "$NS" get pods -l eventsource-name=fleet -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  [ "$ready" = "true" ] && break
  sleep 3
done
[ "$ready" = "true" ] && pass "EventSource fleet has one ready pod" || bad "EventSource fleet has no single ready pod (ready: '$ready')"

port=$(kubectl -n "$NS" get eventsource fleet -o jsonpath='{.spec.webhook.report.port}' 2>/dev/null)
ep=$(kubectl -n "$NS" get eventsource fleet -o jsonpath='{.spec.webhook.report.endpoint}' 2>/dev/null)
[ "$port" = "12000" ] && [ "$ep" = "/report" ] && pass "webhook event report keeps port 12000 and endpoint /report" || bad "webhook event report must keep port 12000 and endpoint /report (got '$port' '$ep')"

exit $fail
