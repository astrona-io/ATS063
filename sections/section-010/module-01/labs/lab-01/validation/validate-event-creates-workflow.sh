#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
msg="lab-$(date +%s)-$RANDOM"

send() {
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST -H 'Content-Type: application/json' \
    -d "{\"message\":\"$msg\"}" http://webhook-eventsource-svc:12000/mission 2>/dev/null
}

found() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$msg" '$1 ~ /^mission-/ && index($2, m) { print $1; exit }'
}

code=""
for attempt in 1 2 3; do
  code=$(send)
  for _ in $(seq 1 10); do
    wf=$(found)
    if [ -n "$wf" ]; then
      echo "PASS: event with message '$msg' created Workflow $wf"
      exit 0
    fi
    sleep 2
  done
done
echo "FAIL: no Workflow named mission-* with message '$msg' appeared (last HTTP status: '$code')"
exit 1
