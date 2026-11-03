#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="ship$(date +%s)$RANDOM"

for _ in $(seq 1 30); do
  es=$(kubectl -n "$NS" get pods -l eventsource-name=fleet --no-headers 2>/dev/null | wc -l | tr -d ' ')
  sn=$(kubectl -n "$NS" get pods -l sensor-name=fleet --no-headers 2>/dev/null | wc -l | tr -d ' ')
  er=$(kubectl -n "$NS" get pods -l eventsource-name=fleet -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  sr=$(kubectl -n "$NS" get pods -l sensor-name=fleet -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  [ "$es" = "1" ] && [ "$sn" = "1" ] && [ "$er" = "true" ] && [ "$sr" = "true" ] && break
  sleep 3
done

before=$(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c 'workflow.argoproj.io/report-')
found=0
for _ in 1 2 3 4 5 6; do
  kubectl -n "$NS" exec shuttle -- curl -s -m 10 -o /dev/null -X POST -H 'Content-Type: application/json' -d "{\"ship\":\"$tag\"}" http://fleet-eventsource-svc:12000/report >/dev/null 2>&1
  for _ in $(seq 1 8); do
    now=$(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c 'workflow.argoproj.io/report-')
    if [ "$now" -gt "$before" ]; then found=1; break; fi
    sleep 2
  done
  [ "$found" = 1 ] && break
done
if [ "$found" != 1 ]; then
  echo "FAIL: a POST to http://fleet-eventsource-svc:12000/report did not create a report- Workflow"
  exit 1
fi
echo "PASS: a request to the Service created a report- Workflow"

for _ in $(seq 1 40); do
  ok=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^report-/ && $2 == "Succeeded"' | wc -l | tr -d ' ')
  if [ "$ok" -ge 1 ]; then
    echo "PASS: a report- Workflow reached the phase Succeeded"
    exit 0
  fi
  sleep 3
done
echo "FAIL: no report- Workflow reached the phase Succeeded"
exit 1
