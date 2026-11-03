#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="ack-$(date +%s)-$RANDOM"
site="$tag"

rows() { # prefix, site -> "name<TAB>phase"
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v p="^$1-" -v s="$2" '$1 ~ p && $2 == s { print $1 "\t" $3 }'
}

r=""
for attempt in 1 2 3 4; do
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"site\":\"$site\"}" "http://beacon-eventsource-svc:12000/ack" >/dev/null 2>&1
  for _ in $(seq 1 15); do
    r=$(rows close "$site")
    [ -n "$r" ] && break
    sleep 3
  done
  [ -n "$r" ] && break
done
if [ -z "$r" ]; then
  echo "FAIL: a request to ack created no close- Workflow"
  exit 1
fi
sleep 15
fail=0
n=$(rows close "$site" | wc -l | tr -d ' ')
[ "$n" = "1" ] && echo "PASS: an acknowledgement created exactly one close- Workflow with the site" || { echo "FAIL: an acknowledgement created $n close- Workflows, expected 1"; fail=1; }
if [ -n "$(rows page "$site")" ]; then
  echo "FAIL: an acknowledgement created a page- Workflow"
  fail=1
else
  echo "PASS: an acknowledgement created no page- Workflow"
fi
name=$(printf '%s\n' "$r" | head -n 1 | awk -F'\t' '{print $1}')
phase=""
for _ in $(seq 1 40); do
  phase=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in Succeeded|Failed|Error) break ;; esac
  sleep 3
done
[ "$phase" = "Succeeded" ] && echo "PASS: the close- Workflow reached Succeeded" || { echo "FAIL: the close- Workflow is '${phase}', expected Succeeded"; fail=1; }
exit $fail
