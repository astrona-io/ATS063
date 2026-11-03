#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
SVC=http://beacon-eventsource-svc

send() { # port path body
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' -d "$3" "$SVC:$1/$2" >/dev/null 2>&1
}
count() { kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '^workflow.argoproj.io/admit-'; }
values() {
  kubectl -n "$NS" get workflows \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}' 2>/dev/null \
    | grep '^admit-' | cut -f2
}
# Wait until exactly one Sensor pod and one EventSource pod exist and are ready, then let the subscription settle.
wait_ready() {
  for _ in $(seq 1 40); do
    ok=1
    for sel in sensor-name=gatekeeper eventsource-name=beacon; do
      total=$(kubectl -n "$NS" get pods -l "$sel" -o name 2>/dev/null | wc -l | tr -d ' ')
      ready=$(kubectl -n "$NS" get pods -l "$sel" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c True)
      if [ "$total" != "1" ] || [ "$ready" != "1" ]; then ok=0; fi
    done
    if [ "$ok" = "1" ]; then sleep 10; return 0; fi
    sleep 3
  done
  return 1
}
# Empty the stored events of the trigger: send a valid dock request, and a clearance only if the dock request did not fire at once.
MARK=""
drain() {
  MARK="drain-$RANDOM$RANDOM"
  send 12000 dock "{\"ship\":\"$MARK\",\"class\":\"scout\",\"fuel\":50}"
  for _ in $(seq 1 5); do values | grep -qix "$MARK"  && { sleep 8; return 0; }; sleep 3; done
  send 13000 clearance '{"code":"granted"}'
  for _ in $(seq 1 20); do values | grep -qix "$MARK" && { sleep 8; return 0; }; sleep 3; done
  return 1
}
# Wait until the number of admit- Workflows reaches $1, for at most 60 seconds.
wait_count() {
  for _ in $(seq 1 20); do [ "$(count)" -ge "$1" ] && return 0; sleep 3; done
  return 1
}
names=$(kubectl -n "$NS" get sensor gatekeeper -o jsonpath='{range .spec.dependencies[*]}{.eventName}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
if [ "$names" != "clearance dock " ]; then
  echo "FAIL: Sensor gatekeeper must keep one dependency on dock and one on clearance, found: ${names:-none}"
  exit 1
fi
echo "PASS: Sensor gatekeeper has the dependencies dock and clearance"

if ! wait_ready; then echo "FAIL: the Sensor pod and the EventSource pod are not ready"; exit 1; fi
if ! drain; then
  echo "FAIL: a valid docking request and a valid clearance created no admit- Workflow within 90 seconds"
  exit 1
fi
wf=""
for line in $(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.arguments.parameters[0].value}{"\n"}{end}' 2>/dev/null | grep '^admit-'); do
  v=${line#*|}
  if [ "$(printf '%s' "$v" | tr 'A-Z' 'a-z')" = "$MARK" ]; then wf=${line%%|*}; fi
done
if [ -z "$wf" ]; then echo "FAIL: the Workflow of the test ship was not found"; exit 1; fi
phase=""
for _ in $(seq 1 40); do
  phase=$(kubectl -n "$NS" get workflow "$wf" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in Succeeded|Failed|Error) break ;; esac
  sleep 3
done
if [ "$phase" = "Succeeded" ]; then
  echo "PASS: the Workflow $wf reached Succeeded"
else
  echo "FAIL: the Workflow $wf has the phase '${phase}', expected Succeeded"
  exit 1
fi
