#!/usr/bin/env bash
set -uo pipefail
fail=0
svc=$(kubectl -n starfleet get ingress gate -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
port=$(kubectl -n starfleet get ingress gate -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
[ "$svc" = "gate-eventsource-svc" ] && echo "PASS: backend Service is gate-eventsource-svc" || { echo "FAIL: backend Service must be gate-eventsource-svc (got '$svc')"; fail=1; }
[ "$port" = "12000" ] && echo "PASS: backend port is 12000" || { echo "FAIL: backend port must be 12000 (got '$port')"; fail=1; }
exit $fail
