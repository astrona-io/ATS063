#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get eventbus signals >/dev/null 2>&1; then
  echo "FAIL: the EventBus signals does not exist in $NS"
  exit 1
fi
deployed=$(kubectl -n "$NS" get eventbus signals -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "the EventBus signals is Deployed" || bad "the EventBus signals is not Deployed (status '${deployed}')"

replicas=$(kubectl -n "$NS" get eventbus signals -o jsonpath='{.spec.jetstream.replicas}' 2>/dev/null)
ready=$(kubectl -n "$NS" get statefulset eventbus-signals-js -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$replicas" = "3" ] && [ "${ready:-0}" = "3" ] && pass "the bus has 3 replicas and 3 ready server pods" || bad "expected 3 replicas and 3 ready pods, found spec '${replicas}' and ready '${ready:-0}'"

for i in 0 1 2; do
  claim="eventbus-signals-js-vol-eventbus-signals-js-$i"
  phase=$(kubectl -n "$NS" get pvc "$claim" -o jsonpath='{.status.phase}' 2>/dev/null)
  size=$(kubectl -n "$NS" get pvc "$claim" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
  [ "$phase" = "Bound" ] && [ "$size" = "1Gi" ] && pass "claim $claim is Bound with 1Gi" || bad "claim $claim is '${phase:-missing}' with '${size:-none}', expected Bound and 1Gi"
done

cfg=$(kubectl -n "$NS" get eventbus signals -o jsonpath='{.status.config.jetstream.streamConfig}' 2>/dev/null)
printf '%s\n' "$cfg" | grep -qiE 'maxage:[[:space:]]*"?12h' && pass "the merged stream configuration has maxAge 12h" || bad "the merged stream configuration in the status of signals has no maxAge of 12h"

if kubectl -n "$NS" get eventbus default >/dev/null 2>&1; then
  bad "an EventBus named default exists; the pipeline must use the bus signals"
else
  pass "no EventBus named default exists"
fi
exit $fail
