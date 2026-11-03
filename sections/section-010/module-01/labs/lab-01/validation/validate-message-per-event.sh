#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
base="lab-$(date +%s)-$RANDOM"

send() {
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 \
    -X POST -H 'Content-Type: application/json' \
    -d "{\"message\":\"$1\"}" http://webhook-eventsource-svc:12000/mission >/dev/null 2>&1
}

names_for() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$1" '$1 ~ /^mission-/ && index($2, m) { print $1 }'
}

send "$base-a"
send "$base-b"
for _ in $(seq 1 40); do
  a=$(names_for "$base-a" | head -n1)
  b=$(names_for "$base-b" | head -n1)
  if [ -n "$a" ] && [ -n "$b" ]; then
    if [ "$a" != "$b" ]; then
      echo "PASS: two events created two Workflows ($a and $b), each with its own message"
      exit 0
    fi
    echo "FAIL: both messages ended in the same Workflow $a"
    exit 1
  fi
  sleep 3
done
echo "FAIL: expected one Workflow for each of two events, found a='$a' b='$b'"
exit 1
