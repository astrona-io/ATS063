#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="lab-$(date +%s)-$RANDOM"

kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"ship\":\"$tag\"}" http://fleet-eventsource-svc:12000/scout >/dev/null 2>&1

for _ in $(seq 1 60); do
  phase=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$tag" '$1 ~ /^launch-/ && $2 == m { print $3 }' | head -n1)
  if [ "$phase" = "Succeeded" ]; then
    echo "PASS: the launch- Workflow for the request reached the phase Succeeded"
    exit 0
  fi
  if [ "$phase" = "Failed" ] || [ "$phase" = "Error" ]; then
    echo "FAIL: the launch- Workflow for the request ended in the phase $phase"
    exit 1
  fi
  sleep 3
done
echo "FAIL: no launch- Workflow with the parameter ship '$tag' reached the phase Succeeded within 180 seconds"
exit 1
