#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

count() { kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '^workflow.argoproj.io/launch-'; }

send() { # port, path, ship
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"ship\":\"$3\"}" "http://fleet-eventsource-svc:$1/$2" >/dev/null 2>&1
}

check_one() { # port, path, label
  local before after grew=0
  before=$(count)
  send "$1" "$2" "either-$RANDOM"
  for _ in $(seq 1 25); do
    after=$(count)
    if [ "$after" -gt "$before" ]; then grew=1; break; fi
    sleep 3
  done
  if [ "$grew" != 1 ]; then
    echo "FAIL: a request to the event $3 created no launch- Workflow within 75 seconds"
    return 1
  fi
  sleep 10
  after=$(count)
  if [ $((after - before)) -ne 1 ]; then
    echo "FAIL: a request to the event $3 created $((after - before)) launch- Workflows, expected 1"
    return 1
  fi
  echo "PASS: a request to the event $3 created exactly one launch- Workflow"
  return 0
}

fail=0
check_one 12000 scout scout || fail=1
check_one 13000 relay relay || fail=1
exit $fail
