#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

kubectl -n "$NS" rollout status deployment -l sensor-name=relay --timeout=120s >/dev/null 2>&1
if ! kubectl -n "$NS" get pod -l sensor-name=relay -o name 2>/dev/null | grep -q pod/; then
  echo "FAIL: Sensor relay has no running pod"
  exit 1
fi

logcount() { kubectl -n "$NS" exec beacon -- sh -c "grep -c -- '$2' /tmp/state/$1 2>/dev/null || true" 2>/dev/null | tr -d '[:space:]'; }

id="cargo-$RANDOM$RANDOM"
kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"id\":\"$id\"}" "http://gate-eventsource-svc:12000/relay" >/dev/null 2>&1

accepted=0
for _ in $(seq 1 30); do
  accepted=$(logcount accepted.log "$id")
  [ "${accepted:-0}" -ge 1 ] && break
  sleep 3
done

if [ "${accepted:-0}" -lt 1 ]; then
  seen=$(logcount requests.log "$id")
  echo "FAIL: the beacon never accepted the message within 90 seconds (it received ${seen:-0} requests for it)"
  exit 1
fi
echo "PASS: the beacon accepted the message after retries"

sleep 5
accepted=$(logcount accepted.log "$id")
if [ "$accepted" = "1" ]; then
  echo "PASS: the message was accepted exactly once"
else
  echo "FAIL: the message was accepted $accepted times, expected 1"
  exit 1
fi
exit 0
