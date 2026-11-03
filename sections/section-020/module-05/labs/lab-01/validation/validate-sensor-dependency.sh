#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

es=$(kubectl -n "$NS" get sensor fleet -o jsonpath='{.spec.dependencies[0].eventSourceName}' 2>/dev/null)
ev=$(kubectl -n "$NS" get sensor fleet -o jsonpath='{.spec.dependencies[0].eventName}' 2>/dev/null)
[ "$es" = "fleet" ] && pass "dependency uses the EventSource fleet" || bad "dependency must use eventSourceName fleet (got '$es')"
[ "$ev" = "report" ] && pass "dependency uses the event report" || bad "dependency must use eventName report (got '$ev')"

exit $fail
