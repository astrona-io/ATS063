#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

if ! kubectl -n "$NS" get sensor ticker >/dev/null 2>&1; then
  echo "FAIL: Sensor ticker not found in $NS"
  exit 1
fi
srcs=$(kubectl -n "$NS" get sensor ticker -o jsonpath='{.spec.dependencies[*].eventSourceName}' 2>/dev/null)
evs=$(kubectl -n "$NS" get sensor ticker -o jsonpath='{.spec.dependencies[*].eventName}' 2>/dev/null)
case " $srcs " in *" ticker "*) ;; *) echo "FAIL: Sensor ticker has no dependency on eventSourceName ticker (got '$srcs')"; exit 1 ;; esac
case " $evs " in *" beat "*) ;; *) echo "FAIL: Sensor ticker has no dependency on eventName beat (got '$evs')"; exit 1 ;; esac
echo "PASS: Sensor ticker depends on ticker/beat"

count() { kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '^workflow.argoproj.io/beat-'; }
before=$(count)
echo "INFO: beat- Workflows before waiting: $before"

grew=0
for _ in $(seq 1 50); do
  now=$(count)
  if [ "$now" -gt "$before" ]; then grew=1; break; fi
  sleep 3
done
if [ "$grew" != 1 ]; then
  echo "FAIL: no new beat- Workflow appeared within 150 seconds"
  exit 1
fi
echo "PASS: a new beat- Workflow appeared"

for _ in $(seq 1 40); do
  phases=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^beat-/ { print $2 }')
  if echo "$phases" | grep -q '^Succeeded$'; then
    echo "PASS: a beat- Workflow reached the phase Succeeded"
    exit 0
  fi
  sleep 3
done
echo "FAIL: no beat- Workflow reached the phase Succeeded"
exit 1
