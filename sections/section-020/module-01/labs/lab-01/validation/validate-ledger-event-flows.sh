#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

count() { kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '^workflow.argoproj.io/ledger-'; }

marker="audit-$RANDOM$RANDOM"
before=$(count)
kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"message\":\"$marker\"}" "http://ledger-eventsource-svc:12000/entry" >/dev/null 2>&1

found=""
for _ in $(seq 1 40); do
  if [ "$(count)" -gt "$before" ]; then
    found=$(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep '^workflow.argoproj.io/ledger-' | tail -n 1)
    break
  fi
  sleep 3
done
if [ -z "$found" ]; then
  echo "FAIL: a request to the webhook created no ledger- Workflow within 120 seconds"
  exit 1
fi
echo "PASS: a request to the webhook created a ledger- Workflow"

fail=0
# Find the Workflow that carries this request, not an older one.
wf=""
for w in $(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep '^workflow.argoproj.io/ledger-'); do
  v=$(kubectl -n "$NS" get "$w" -o jsonpath='{.spec.arguments.parameters[0].value}' 2>/dev/null)
  if [ "$v" = "$marker" ]; then wf="$w"; break; fi
done
if [ -n "$wf" ]; then
  echo "PASS: the Workflow carries the message from the request"
else
  echo "FAIL: no ledger- Workflow has the first parameter value $marker"
  exit 1
fi

phase=""
for _ in $(seq 1 40); do
  phase=$(kubectl -n "$NS" get "$wf" -o jsonpath='{.status.phase}' 2>/dev/null)
  case "$phase" in Succeeded|Failed|Error) break ;; esac
  sleep 3
done
if [ "$phase" = "Succeeded" ]; then
  echo "PASS: the Workflow reached Succeeded"
else
  echo "FAIL: the Workflow phase is '${phase}', expected Succeeded"
  fail=1
fi
exit $fail
