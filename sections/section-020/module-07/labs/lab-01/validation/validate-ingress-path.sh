#!/usr/bin/env bash
set -uo pipefail
path=$(kubectl -n starfleet get ingress gate -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
host=$(kubectl -n starfleet get ingress gate -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
[ "$host" = "gate.example.test" ] || { echo "FAIL: the host must stay gate.example.test (got '$host')"; exit 1; }
[ "$path" = "/report" ] && { echo "PASS: path is /report"; exit 0; }
echo "FAIL: path must be /report, the endpoint of the webhook event (got '$path')"; exit 1
