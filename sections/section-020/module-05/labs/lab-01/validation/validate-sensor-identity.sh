#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

sa=""
for _ in $(seq 1 20); do
  sa=$(kubectl -n "$NS" get pods -l sensor-name=fleet -o jsonpath='{.items[0].spec.serviceAccountName}' 2>/dev/null)
  [ -n "$sa" ] && [ "$sa" != "default" ] && break
  sleep 3
done
if [ -z "$sa" ]; then
  bad "no pod of the Sensor fleet was found"
  exit 1
fi
answer=$(kubectl auth can-i create workflows.argoproj.io -n "$NS" --as="system:serviceaccount:$NS:$sa" 2>/dev/null)
if [ "$answer" = "yes" ]; then
  pass "the Sensor pod runs as $sa, which may create Workflows"
else
  bad "the Sensor pod runs as '$sa', which may not create Workflows in $NS"
fi

rules=$(kubectl -n "$NS" get role event-trigger -o jsonpath='{.rules[0].verbs[*]}' 2>/dev/null)
[ "$rules" = "create" ] && pass "the Role event-trigger is unchanged" || bad "the Role event-trigger must stay unchanged (verbs: '$rules')"

exit $fail
