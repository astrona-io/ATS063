#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

name=$(kubectl -n "$NS" get eventsource dispatch -o jsonpath='{.spec.webhook.order.authSecret.name}' 2>/dev/null)
key=$(kubectl -n "$NS" get eventsource dispatch -o jsonpath='{.spec.webhook.order.authSecret.key}' 2>/dev/null)
[ "$name" = "dispatch-token" ] && pass "event order uses the Secret dispatch-token" || bad "event order must set authSecret.name to dispatch-token (got '$name')"
[ "$key" = "token" ] && pass "event order uses the key token" || bad "event order must set authSecret.key to token (got '$key')"

endpoint=$(kubectl -n "$NS" get eventsource dispatch -o jsonpath='{.spec.webhook.order.endpoint}' 2>/dev/null)
port=$(kubectl -n "$NS" get eventsource dispatch -o jsonpath='{.spec.webhook.order.port}' 2>/dev/null)
[ "$endpoint" = "/order" ] && [ "$port" = "12000" ] && pass "event order is still on port 12000 at /order" || bad "event order must stay on port 12000 at /order (got '$port' '$endpoint')"

secret=$(kubectl -n "$NS" get secret dispatch-token -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode 2>/dev/null)
[ "$secret" = "fleet-4417-orbit" ] && pass "the Secret dispatch-token is unchanged" || bad "the Secret dispatch-token must not be changed"

exit $fail
