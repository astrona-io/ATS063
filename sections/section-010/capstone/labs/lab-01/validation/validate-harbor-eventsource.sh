#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get eventsource harbor >/dev/null 2>&1; then
  echo "FAIL: EventSource harbor not found in $NS"
  exit 1
fi
for ev in arrival departure; do
  port=$(kubectl -n "$NS" get eventsource harbor -o jsonpath="{.spec.webhook.$ev.port}" 2>/dev/null)
  ep=$(kubectl -n "$NS" get eventsource harbor -o jsonpath="{.spec.webhook.$ev.endpoint}" 2>/dev/null)
  name=$(kubectl -n "$NS" get eventsource harbor -o jsonpath="{.spec.webhook.$ev.authSecret.name}" 2>/dev/null)
  key=$(kubectl -n "$NS" get eventsource harbor -o jsonpath="{.spec.webhook.$ev.authSecret.key}" 2>/dev/null)
  [ "$port" = "12000" ] && [ "$ep" = "/$ev" ] && pass "event $ev listens on port 12000 at /$ev" || bad "event $ev must listen on port 12000 at /$ev (got '$port' '$ep')"
  [ "$name" = "harbor-token" ] && [ "$key" = "token" ] && pass "event $ev reads its token from harbor-token key token" || bad "event $ev must set authSecret name harbor-token and key token (got '$name' '$key')"
done
deployed=$(kubectl -n "$NS" get eventsource harbor -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource harbor is Deployed" || bad "EventSource harbor is not Deployed (status '${deployed}')"
secret=$(kubectl -n "$NS" get secret harbor-token -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode 2>/dev/null)
[ "$secret" = "dock-9917-orbit" ] && pass "the Secret harbor-token is unchanged" || bad "the Secret harbor-token must not be changed"
exit $fail
