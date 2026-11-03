#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
tag="esc-$(date +%s)-$RANDOM"

send() { # level, site
  kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"level\":\"$1\",\"site\":\"$2\"}" "http://beacon-eventsource-svc:12000/alert" >/dev/null 2>&1
}
rows() { # prefix, site -> "name<TAB>phase"
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v p="^$1-" -v s="$2" '$1 ~ p && $2 == s { print $1 "\t" $3 }'
}

fail=0
site="$tag-crit"
r=""
for attempt in 1 2 3 4; do
  send critical "$site"
  for _ in $(seq 1 15); do
    r=$(rows page "$site")
    [ -n "$r" ] && break
    sleep 3
  done
  [ -n "$r" ] && break
done
if [ -z "$r" ]; then
  echo "FAIL: a request to alert with level critical created no page- Workflow"
  exit 1
fi
sleep 15
n=$(rows page "$site" | wc -l | tr -d ' ')
[ "$n" = "1" ] && echo "PASS: a critical alert created exactly one page- Workflow with the site" || { echo "FAIL: a critical alert created $n page- Workflows, expected 1 (a retry that sent the alert again can add more)"; fail=1; }

name=$(printf '%s\n' "$r" | head -n 1 | awk -F'\t' '{print $1}')
phase=""
for _ in $(seq 1 40); do
  phase=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in Succeeded|Failed|Error) break ;; esac
  sleep 3
done
[ "$phase" = "Succeeded" ] && echo "PASS: the page- Workflow reached Succeeded" || { echo "FAIL: the page- Workflow is '${phase}', expected Succeeded"; fail=1; }

for level in info warning Critical; do
  send "$level" "$tag-$level"
done
sleep 25
for level in info warning Critical; do
  if [ -n "$(rows page "$tag-$level")" ]; then
    echo "FAIL: an alert with level '$level' created a page- Workflow"
    fail=1
  else
    echo "PASS: an alert with level '$level' created no page- Workflow"
  fi
done
exit $fail
