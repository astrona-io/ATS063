#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

# Prints "cpu-request memory-request cpu-limit memory-limit" of the main container for every pod that is not being deleted.
resources_of() {
  local names p
  names=$(kubectl -n "$NS" get pods -l "$1" -o custom-columns=NAME:.metadata.name,DEL:.metadata.deletionTimestamp --no-headers 2>/dev/null | awk '$2=="<none>" {print $1}')
  for p in $names; do
    kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.containers[?(@.name=="main")].resources.requests.cpu} {.spec.containers[?(@.name=="main")].resources.requests.memory} {.spec.containers[?(@.name=="main")].resources.limits.cpu} {.spec.containers[?(@.name=="main")].resources.limits.memory}{"\n"}' 2>/dev/null
  done
}

check() {
  local label="$1" want="$2" what="$3" out line bad=0 n=0
  for _ in $(seq 1 30); do
    out=$(resources_of "$label")
    bad=0; n=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      n=$((n + 1))
      [ "$line" = "$want" ] || bad=1
    done <<< "$out"
    [ "$n" -ge 1 ] && [ "$bad" = "0" ] && break
    sleep 3
  done
  if [ "$n" -ge 1 ] && [ "$bad" = "0" ]; then
    echo "PASS: the $what pods have requests 50m/64Mi and the expected limits"
  else
    echo "FAIL: a $what pod does not have the expected resources (want: cpu request, memory request, cpu limit, memory limit = $want; found: $(echo "$out" | tr '\n' ';'))"
    fail=1
  fi
}

check eventsource-name=beacon "50m 64Mi 200m 128Mi" EventSource
check sensor-name=beacon "50m 64Mi 200m 256Mi" Sensor
exit $fail
