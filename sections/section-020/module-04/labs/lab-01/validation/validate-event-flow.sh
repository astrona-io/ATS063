#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

# The calendar produces an event every 20 seconds. Wait for a Workflow created after this moment.
start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
wf=""
for _ in $(seq 1 50); do
  wf=$(kubectl -n "$NS" get workflows -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp --no-headers 2>/dev/null \
    | awk -v s="$start" '$1 ~ /^beacon-/ && $2 > s {print $1}' | tail -n 1)
  [ -n "$wf" ] && break
  sleep 3
done
if [ -z "$wf" ]; then
  echo "FAIL: no new beacon- Workflow was created within 150 seconds, so no calendar event reached the Sensor"
  exit 1
fi
echo "PASS: the calendar event created the Workflow $wf"

phase=""
for _ in $(seq 1 40); do
  phase=$(kubectl -n "$NS" get workflow "$wf" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in Succeeded|Failed|Error) break ;; esac
  sleep 3
done
if [ "$phase" = "Succeeded" ]; then
  echo "PASS: the Workflow $wf reached Succeeded"
  exit 0
fi
echo "FAIL: the Workflow $wf has phase '${phase}', expected Succeeded"
exit 1
