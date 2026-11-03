#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get sensor mission >/dev/null 2>&1; then
  echo "FAIL: Sensor mission not found in $NS"
  exit 1
fi
pass "Sensor mission exists"

srcs=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.dependencies[*].eventSourceName}' 2>/dev/null)
evs=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.dependencies[*].eventName}' 2>/dev/null)
case " $srcs " in *" webhook "*) pass "a dependency uses eventSourceName webhook" ;; *) bad "no dependency has eventSourceName webhook (got '$srcs')" ;; esac
case " $evs " in *" mission "*) pass "a dependency uses eventName mission" ;; *) bad "no dependency has eventName mission (got '$evs')" ;; esac

op=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.triggers[*].template.k8s.operation}' 2>/dev/null)
kind=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.triggers[*].template.k8s.source.resource.kind}' 2>/dev/null)
gen=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.triggers[*].template.k8s.source.resource.metadata.generateName}' 2>/dev/null)
[ "$op" = "create" ] && pass "trigger operation is create" || bad "trigger must be a k8s trigger with operation create (got '$op')"
[ "$kind" = "Workflow" ] && pass "trigger creates a Workflow" || bad "trigger must create a Workflow (got '$kind')"
[ "$gen" = "mission-" ] && pass "Workflow generateName is mission-" || bad "Workflow metadata.generateName must be mission- (got '$gen')"

sa=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.spec.template.serviceAccountName}' 2>/dev/null)
[ "$sa" = "event-trigger" ] && pass "Sensor runs as event-trigger" || bad "Sensor must run as service account event-trigger (got '$sa')"

deployed=$(kubectl -n "$NS" get sensor mission -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "Sensor is deployed" || bad "Sensor condition Deployed is '$deployed', expected True"

exit $fail
