#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

if ! kubectl -n "$NS" get eventbus audit >/dev/null 2>&1; then
  echo "FAIL: the EventBus audit does not exist in $NS"
  exit 1
fi

deployed=$(kubectl -n "$NS" get eventbus audit -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
if [ "$deployed" = "True" ]; then
  echo "PASS: the EventBus audit is Deployed"
else
  echo "FAIL: the EventBus audit is not Deployed (condition status: '${deployed}')"
  fail=1
fi

replicas=$(kubectl -n "$NS" get eventbus audit -o jsonpath='{.spec.jetstream.replicas}' 2>/dev/null)
ready=$(kubectl -n "$NS" get statefulset eventbus-audit-js -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$replicas" = "3" ] && [ "${ready:-0}" = "3" ]; then
  echo "PASS: the bus audit has 3 replicas and 3 ready server pods"
else
  echo "FAIL: expected 3 replicas and 3 ready pods, found spec replicas '${replicas}' and ready pods '${ready:-0}'"
  fail=1
fi

cfg=$(kubectl -n "$NS" get eventbus audit -o jsonpath='{.status.config.jetstream.streamConfig}' 2>/dev/null)
if printf '%s\n' "$cfg" | grep -qiE 'maxage:[[:space:]]*"?24h'; then
  echo "PASS: the merged stream configuration has maxAge 24h"
else
  echo "FAIL: the merged stream configuration in the status of audit has no maxAge of 24h"
  fail=1
fi
if printf '%s\n' "$cfg" | grep -qiE 'maxmsgs:[[:space:]]*1000([^0-9]|$)'; then
  echo "PASS: the merged stream configuration has maxMsgs 1000"
else
  echo "FAIL: the merged stream configuration in the status of audit has no maxMsgs of 1000"
  fail=1
fi
exit $fail
