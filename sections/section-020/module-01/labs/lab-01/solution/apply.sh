#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-063-lab-020-01-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-063-lab-020-01-01-control-plane"
worker_name="astro-ats-063-lab-020-01-01-worker"

kubectl apply -f "$solution_directory/eventbus-default.yaml"
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True eventbus/default --timeout=300s
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True eventsource/webhook --timeout=180s
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True sensor/mission --timeout=180s
kubectl -n starfleet exec shuttle -- python -c 'import urllib.request,json; r=urllib.request.Request('"'"'http://webhook-eventsource-svc:12000/mission'"'"',data=json.dumps({'"'"'id'"'"':'"'"'mission-complete'"'"'}).encode(),headers={'"'"'Content-Type'"'"':'"'"'application/json'"'"'}); print(urllib.request.urlopen(r,timeout=5).status)'
for attempt in $(seq 1 30); do
  if kubectl -n starfleet get workflow/event-mission >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded workflow/event-mission --timeout=240s
