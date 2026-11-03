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
if ! wait_ready; then echo "FAIL: the Sensor pod and the EventSource pod are not ready"; exit 1; fi
if ! drain; then
  echo "FAIL: a valid docking request and a valid clearance created no admit- Workflow within 90 seconds"
  exit 1
fi
echo "PASS: a valid docking request with a clearance starts a Workflow"

fail=0
check_dropped() { # label, body
  base=$(count)
  send 12000 dock "$2"
  send 13000 clearance '{"code":"granted"}'
  sleep 12
  if [ "$(count)" -gt "$base" ]; then
    echo "FAIL: $1 started a Workflow but must be dropped"
    fail=1
  else
    echo "PASS: $1 is dropped"
  fi
}
check_dropped "fuel 19" '{"ship":"n1","class":"scout","fuel":19}'
check_dropped "class scoutship" '{"ship":"n2","class":"scoutship","fuel":50}'
check_dropped "class freighter" '{"ship":"n3","class":"freighter","fuel":50}'
check_dropped "a request without fuel" '{"ship":"n4","class":"scout"}'

# A clearance is stored from the last case when the conditions are right, so a valid dock request completes the pair.
base=$(count)
send 12000 dock '{"ship":"edge","class":"scout","fuel":20}'
if wait_count $((base + 1)); then
  echo "PASS: fuel of exactly 20 is accepted"
else
  echo "FAIL: a docking request with fuel 20 and class scout created no Workflow within 60 seconds"
  fail=1
fi
exit $fail
