#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="lab-$(date +%s)-$RANDOM"

send() { # port, path, ship
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"ship\":\"$3\"}" "http://fleet-eventsource-svc:$1/$2" >/dev/null 2>&1
}

has() { # exact parameter value
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$1" '$1 ~ /^launch-/ && $2 == m { found=1 } END { exit found ? 0 : 1 }'
}

fail=0
for pair in "12000 scout" "13000 relay"; do
  set -- $pair
  ship="$tag-$2"
  send "$1" "$2" "$ship"
  ok=0
  for _ in $(seq 1 25); do
    if has "$ship"; then ok=1; break; fi
    sleep 3
  done
  if [ "$ok" = 1 ]; then
    echo "PASS: a request to the event $2 created a Workflow whose parameter ship is '$ship'"
  else
    echo "FAIL: no launch- Workflow has the parameter ship '$ship' after a request to the event $2"
    fail=1
  fi
done
exit $fail
