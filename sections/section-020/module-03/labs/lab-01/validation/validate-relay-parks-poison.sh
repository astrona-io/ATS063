#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

kubectl -n "$NS" rollout status deployment -l sensor-name=relay --timeout=120s >/dev/null 2>&1

logcount() { kubectl -n "$NS" exec beacon -- sh -c "grep -c -- '$2' /tmp/state/$1 2>/dev/null || true" 2>/dev/null | tr -d '[:space:]'; }

id="poison-$RANDOM$RANDOM"
kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"id\":\"$id\"}" "http://gate-eventsource-svc:12000/relay" >/dev/null 2>&1

dead=0
for _ in $(seq 1 30); do
  dead=$(logcount dead.log "$id")
  [ "${dead:-0}" -ge 1 ] && break
  sleep 3
done

fail=0
if [ "${dead:-0}" -ge 1 ]; then
  echo "PASS: the rejected message reached the dead letter endpoint"
else
  echo "FAIL: the rejected message was not stored on /cgi-bin/dead within 90 seconds"
  exit 1
fi

sleep 5
dead=$(logcount dead.log "$id")
if [ "$dead" = "1" ]; then
  echo "PASS: the message was parked exactly once"
else
  echo "FAIL: the message was parked $dead times, expected 1"
  fail=1
fi

accepted=$(logcount accepted.log "$id")
if [ "${accepted:-0}" = "0" ]; then
  echo "PASS: the rejected message was never accepted"
else
  echo "FAIL: the beacon accepted the message that it must always reject"
  fail=1
fi

attempts=$(logcount requests.log "$id")
if [ "${attempts:-0}" -ge 3 ] && [ "${attempts:-0}" -le 10 ]; then
  echo "PASS: the Sensor tried $attempts times before it gave up"
else
  echo "FAIL: the Sensor tried ${attempts:-0} times, expected between 3 and 10"
  fail=1
fi
exit $fail
