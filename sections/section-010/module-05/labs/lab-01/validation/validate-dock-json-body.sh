#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
json=$(kubectl -n "$NS" get eventsource dock -o jsonpath='{.spec.kafka.arrival.jsonBody}' 2>/dev/null)
if [ "$json" = "true" ]; then
  echo "PASS: event arrival has jsonBody true"
  exit 0
fi
echo "FAIL: event arrival must set jsonBody to true (got '$json')"
exit 1
