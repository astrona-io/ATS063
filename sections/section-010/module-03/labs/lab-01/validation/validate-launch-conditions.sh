#!/usr/bin/env bash
set -uo pipefail
NS=starfleet

if ! kubectl -n "$NS" get sensor launch >/dev/null 2>&1; then
  echo "FAIL: Sensor launch not found in $NS"
  exit 1
fi
srcs=$(kubectl -n "$NS" get sensor launch -o jsonpath='{.spec.dependencies[*].eventSourceName}' 2>/dev/null)
evs=$(kubectl -n "$NS" get sensor launch -o jsonpath='{.spec.dependencies[*].eventName}' 2>/dev/null)
case " $evs " in *" scout "*) ;; *) echo "FAIL: Sensor launch has no dependency on the event scout (got '$evs')"; exit 1 ;; esac
case " $evs " in *" relay "*) ;; *) echo "FAIL: Sensor launch has no dependency on the event relay (got '$evs')"; exit 1 ;; esac
for s in $srcs; do
  if [ "$s" != "fleet" ]; then
    echo "FAIL: a dependency of Sensor launch points at EventSource '$s' and not at fleet"
    exit 1
  fi
done
echo "PASS: Sensor launch still depends on the events scout and relay of fleet"

cond=$(kubectl -n "$NS" get sensor launch -o jsonpath='{.spec.triggers[0].template.conditions}' 2>/dev/null)
if [ -z "$cond" ]; then
  echo "FAIL: the trigger has no conditions, so it waits for every dependency"
  exit 1
fi
case "$cond" in
  *"&&"*) echo "FAIL: the conditions '$cond' contain && and wait for both events"; exit 1 ;;
esac
case "$cond" in
  *"||"*) ;;
  *) echo "FAIL: the conditions '$cond' do not contain ||"; exit 1 ;;
esac
echo "PASS: the trigger conditions are '$cond'"
exit 0
