#!/usr/bin/env bash
set -uo pipefail
for _ in $(seq 1 12); do
  out=$(kubectl -n starfleet exec shuttle -- curl -s -G http://prometheus.starfleet.svc:9090/api/v1/query --data-urlencode 'query=up{job="argo-events-controller"} == 1' 2>/dev/null)
  if echo "$out" | grep -Fq '"job":"argo-events-controller"'; then echo "PASS: the target argo-events-controller is up"; exit 0; fi
  sleep 5
done
echo "FAIL: Prometheus does not report an up target for the job argo-events-controller"; exit 1
