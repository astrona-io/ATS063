#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

kubectl -n "$NS" rollout status deployment -l sensor-name=relay --timeout=120s >/dev/null 2>&1

logcount() { kubectl -n "$NS" exec beacon -- sh -c "grep -c -- '$2' /tmp/state/$1 2>/dev/null || true" 2>/dev/null | tr -d '[:space:]'; }

base="burst-$RANDOM$RANDOM"
for n in 1 2 3; do
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"id\":\"$base-$n\"}" "http://gate-eventsource-svc:12000/relay" >/dev/null 2>&1
done

fail=0
for n in 1 2 3; do
  got=0
  for _ in $(seq 1 40); do
    got=$(logcount accepted.log "$base-$n")
    [ "${got:-0}" -ge 1 ] && break
    sleep 3
  done
  if [ "${got:-0}" -ge 1 ]; then
    echo "PASS: message $n of 3 was accepted"
  else
    echo "FAIL: message $n of 3 was not accepted within 120 seconds"
    fail=1
  fi
done

dead=$(logcount dead.log "$base")
if [ "${dead:-0}" = "0" ]; then
  echo "PASS: no message of the burst was dead-lettered"
else
  echo "FAIL: $dead messages of the burst were stored on the dead letter endpoint"
  fail=1
fi
exit $fail
