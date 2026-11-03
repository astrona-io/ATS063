#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0

# Names of pods that are not being deleted.
live_pods() {
  kubectl -n "$NS" get pods -l "$1" --field-selector=status.phase=Running \
    -o custom-columns=NAME:.metadata.name,DEL:.metadata.deletionTimestamp --no-headers 2>/dev/null \
    | awk '$2=="<none>" {print $1}'
}

replicas=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$replicas" = "2" ]; then
  echo "PASS: spec.replicas of EventSource beacon is 2"
else
  echo "FAIL: spec.replicas of EventSource beacon is '${replicas:-unset}', expected 2"
  fail=1
fi

ann=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.metadata.annotations.events\.argoproj\.io/leader-election}' 2>/dev/null)
if [ "$ann" = "k8s" ]; then
  echo "PASS: the annotation events.argoproj.io/leader-election is k8s"
else
  echo "FAIL: the annotation events.argoproj.io/leader-election is '${ann:-missing}', expected k8s"
  fail=1
fi

sa=$(kubectl -n "$NS" get eventsource beacon -o jsonpath='{.spec.template.serviceAccountName}' 2>/dev/null)
case "$sa" in
  ""|default|event-trigger|workflow-runner)
    echo "FAIL: spec.template.serviceAccountName is '${sa:-unset}', expected a dedicated service account for the EventSource pods"
    fail=1 ;;
  *)
    echo "PASS: the EventSource pods use the dedicated service account $sa" ;;
esac

ready=0
for _ in $(seq 1 40); do
  pods=$(live_pods eventsource-name=beacon)
  ready=0
  for p in $pods; do
    pod_sa=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
    ok=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$ok" = "True" ] && [ "$pod_sa" = "$sa" ]; then ready=$((ready + 1)); fi
  done
  [ "$ready" = "2" ] && [ "$(echo "$pods" | wc -w | tr -d ' ')" = "2" ] && break
  sleep 3
done
if [ "$ready" = "2" ] && [ -n "$sa" ]; then
  echo "PASS: two EventSource pods are Running and Ready with the service account from the spec"
else
  echo "FAIL: found $ready ready EventSource pods with the service account '${sa}', expected exactly 2"
  fail=1
fi
exit $fail
