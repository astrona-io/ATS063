#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
before=$(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '/gate-')
code=000
for _ in $(seq 1 12); do
  code=$(kubectl -n "$NS" exec shuttle -- curl -s -m 10 -o /dev/null -w '%{http_code}' -H 'Host: gate.example.test' -X POST -d '{}' http://ingress-nginx-controller.ingress-nginx.svc/report 2>/dev/null)
  [ "$code" = "200" ] && break
  sleep 5
done
[ "$code" = "200" ] && echo "PASS: the ingress controller returned 200" || { echo "FAIL: POST through the controller returned '$code', expected 200"; exit 1; }
for _ in $(seq 1 30); do
  after=$(kubectl -n "$NS" get workflows -o name 2>/dev/null | grep -c '/gate-')
  [ "$after" -gt "$before" ] && break
  sleep 3
done
[ "$after" -gt "$before" ] || { echo "FAIL: no new gate- Workflow appeared"; exit 1; }
echo "PASS: a gate- Workflow was created"
for _ in $(seq 1 40); do
  phases=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep '^gate-' | awk '{print $2}')
  echo "$phases" | grep -q Succeeded && { echo "PASS: a gate- Workflow succeeded"; exit 0; }
  sleep 3
done
echo "FAIL: no gate- Workflow succeeded"; exit 1
