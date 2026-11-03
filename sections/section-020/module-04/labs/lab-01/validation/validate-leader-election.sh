#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

live_pods() {
  kubectl -n "$NS" get pods -l "$1" --field-selector=status.phase=Running \
    -o custom-columns=NAME:.metadata.name,DEL:.metadata.deletionTimestamp --no-headers 2>/dev/null \
    | awk '$2=="<none>" {print $1}'
}
holder() { kubectl -n "$NS" get lease eventsource-beacon -o jsonpath='{.spec.holderIdentity}' 2>/dev/null; }
in_list() { for x in $2; do [ "$x" = "$1" ] && return 0; done; return 1; }

sa=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.spec.template.serviceAccountName}' 2>/dev/null)
if [ -z "$sa" ] || [ "$sa" = "default" ]; then
  echo "FAIL: the EventSource has no dedicated service account, so the pods cannot be granted lease access on their own"
  exit 1
fi
who="system:serviceaccount:$NS:$sa"

for verb in get create update; do
  ans=$(kubectl auth can-i "$verb" leases.coordination.k8s.io -n "$NS" --as="$who" 2>/dev/null)
  if [ "$ans" = "yes" ]; then
    echo "PASS: $sa may $verb leases in $NS"
  else
    echo "FAIL: $sa may not $verb leases in $NS"
    fail=1
  fi
done
for res in pods secrets deployments; do
  ans=$(kubectl auth can-i list "$res" -n "$NS" --as="$who" 2>/dev/null)
  if [ "$ans" = "yes" ]; then
    echo "FAIL: $sa may list $res, the Role must grant only what leader election needs"
    fail=1
  fi
done
[ "$fail" = "0" ] && echo "PASS: $sa has no broader read access to pods, secrets or deployments"
[ "$fail" != "0" ] && exit 1

# The Lease must name a live pod of the EventSource.
first=""
pods=""
for _ in $(seq 1 40); do
  pods=$(live_pods eventsource-name=beacon)
  first=$(holder)
  if [ -n "$first" ] && in_list "$first" "$pods"; then break; fi
  first=""
  sleep 3
done
if [ -z "$first" ]; then
  echo "FAIL: the Lease eventsource-beacon does not name a running EventSource pod within 120 seconds"
  exit 1
fi
echo "PASS: the Lease eventsource-beacon is held by the running pod $first"

# Delete the leader and wait for another pod to take the lease.
kubectl -n "$NS" delete pod "$first" --wait=false >/dev/null 2>&1
moved=""
for _ in $(seq 1 40); do
  now=$(holder)
  pods=$(live_pods eventsource-name=beacon)
  if [ -n "$now" ] && [ "$now" != "$first" ] && in_list "$now" "$pods"; then moved="$now"; break; fi
  sleep 3
done
if [ -z "$moved" ]; then
  echo "FAIL: after deleting the leader $first the lease did not move to another running pod within 120 seconds"
  fail=1
else
  echo "PASS: after deleting the leader the lease moved to $moved"
fi

# Leave two ready pods behind for the next check.
for _ in $(seq 1 40); do
  ready=$(kubectl -n "$NS" get deployment -l eventsource-name=beacon -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
  [ "$ready" = "2" ] && break
  sleep 3
done
exit $fail
