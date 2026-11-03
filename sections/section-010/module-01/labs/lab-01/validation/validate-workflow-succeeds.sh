#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
msg="lab-run-$(date +%s)-$RANDOM"

kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 \
  -X POST -H 'Content-Type: application/json' \
  -d "{\"message\":\"$msg\"}" http://webhook-eventsource-svc:12000/mission >/dev/null 2>&1

wf=""
for _ in $(seq 1 30); do
  wf=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$msg" '$1 ~ /^mission-/ && index($2, m) { print $1; exit }')
  [ -n "$wf" ] && break
  sleep 2
done
if [ -z "$wf" ]; then
  echo "FAIL: no Workflow was created for message '$msg'"
  exit 1
fi

for _ in $(seq 1 60); do
  phase=$(kubectl -n "$NS" get workflow "$wf" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in
    Succeeded) echo "PASS: Workflow $wf finished with phase Succeeded"; exit 0 ;;
    Failed|Error) echo "FAIL: Workflow $wf ended with phase $phase"; exit 1 ;;
  esac
  sleep 3
done
echo "FAIL: Workflow $wf did not reach Succeeded in time (phase: '${phase:-none}')"
exit 1
