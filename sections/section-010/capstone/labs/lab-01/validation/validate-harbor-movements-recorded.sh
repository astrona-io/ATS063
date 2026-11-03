#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
token=$(kubectl -n "$NS" get secret harbor-token -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode 2>/dev/null)
tag="mv-$(date +%s)-$RANDOM"

send() { # event, ship
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
    -d "{\"ship\":\"$2\"}" "http://harbor-eventsource-svc:12000/$1" >/dev/null 2>&1
}
# Prints "name<TAB>ship<TAB>movement<TAB>phase" for every logbook- Workflow whose first parameter is the ship.
rows() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\t"}{.spec.arguments.parameters[1].value}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v s="$1" '$1 ~ /^logbook-/ && $2 == s'
}

fail=0
for ev in arrival departure; do
  ship="$tag-$ev"
  send "$ev" "$ship"
  r=""
  for _ in $(seq 1 40); do
    r=$(rows "$ship")
    [ -n "$r" ] && break
    sleep 3
  done
  if [ -z "$r" ]; then
    echo "FAIL: a request to $ev created no logbook- Workflow with the ship $ship in its first parameter"
    fail=1
    continue
  fi
  n=$(printf '%s\n' "$r" | wc -l | tr -d ' ')
  [ "$n" = "1" ] && echo "PASS: a request to $ev created exactly one Workflow" || { echo "FAIL: a request to $ev created $n Workflows, expected 1"; fail=1; }
  mv=$(printf '%s\n' "$r" | head -n 1 | awk -F'\t' '{print $3}')
  [ "$mv" = "$ev" ] && echo "PASS: the second parameter holds the event name $ev" || { echo "FAIL: the second parameter is '$mv', expected $ev"; fail=1; }
  name=$(printf '%s\n' "$r" | head -n 1 | awk -F'\t' '{print $1}')
  phase=""
  for _ in $(seq 1 40); do
    phase=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.status.phase}' 2>/dev/null)
    case "$phase" in Succeeded|Failed|Error) break ;; esac
    sleep 3
  done
  [ "$phase" = "Succeeded" ] && echo "PASS: the Workflow for $ev reached Succeeded" || { echo "FAIL: the Workflow for $ev is '${phase}', expected Succeeded"; fail=1; }
done
exit $fail
