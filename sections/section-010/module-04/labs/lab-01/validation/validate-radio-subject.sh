#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

subject=$(kubectl -n "$NS" get eventsource radio -o jsonpath='{.spec.nats.arrival.subject}' 2>/dev/null)
url=$(kubectl -n "$NS" get eventsource radio -o jsonpath='{.spec.nats.arrival.url}' 2>/dev/null)
[ "$subject" = "fleet.arrival" ] && pass "event arrival subscribes to fleet.arrival" || bad "event arrival must subscribe to fleet.arrival (got '$subject')"
[ "$url" = "nats://nats.starfleet.svc:4222" ] && pass "event arrival still uses the NATS Service of starfleet" || bad "the url of event arrival must stay nats://nats.starfleet.svc:4222 (got '$url')"

deployed=$(kubectl -n "$NS" get eventsource radio -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource radio is deployed" || bad "EventSource radio condition Deployed is '$deployed', expected True"

exit $fail
