#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="ship$(date +%s)$RANDOM"

for _ in $(seq 1 30); do
  n=$(kubectl -n "$NS" get pods -l eventsource-name=radio --no-headers 2>/dev/null | wc -l | tr -d ' ')
  ready=$(kubectl -n "$NS" get pods -l eventsource-name=radio -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  [ "$n" = "1" ] && [ "$ready" = "true" ] && break
  sleep 3
done

find_workflow() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v t="$tag" '$1 ~ /^arrival-/ && $2 == t { print $3; found=1 } END { exit found ? 0 : 1 }'
}

found=0
for _ in 1 2 3 4 5 6; do
  kubectl -n "$NS" exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 fleet.arrival "{\"ship\":\"$tag\"}" >/dev/null 2>&1
  for _ in $(seq 1 8); do
    if find_workflow >/dev/null; then found=1; break; fi
    sleep 2
  done
  [ "$found" = 1 ] && break
done
if [ "$found" != 1 ]; then
  echo "FAIL: a message {\"ship\":\"$tag\"} on fleet.arrival did not create an arrival- Workflow with the parameter ship set to $tag"
  exit 1
fi
echo "PASS: an arrival- Workflow carries the ship from the message"

for _ in $(seq 1 40); do
  phase=$(find_workflow | head -n1)
  if [ "$phase" = "Succeeded" ]; then
    echo "PASS: the Workflow reached the phase Succeeded"
    exit 0
  fi
  sleep 3
done
echo "FAIL: the Workflow did not reach the phase Succeeded"
exit 1
