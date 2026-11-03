#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
token=$(kubectl -n "$NS" get secret dispatch-token -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode 2>/dev/null)
tag="lab-$(date +%s)-$RANDOM"

send() { # message, optional authorization header value
  if [ -n "${2:-}" ]; then
    kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
      -H 'Content-Type: application/json' -H "Authorization: $2" \
      -d "{\"message\":\"$1\"}" http://dispatch-eventsource-svc:12000/order >/dev/null 2>&1
  else
    kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"message\":\"$1\"}" http://dispatch-eventsource-svc:12000/order >/dev/null 2>&1
  fi
}

has() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$1" '$1 ~ /^order-/ && index($2, m) { found=1 } END { exit found ? 0 : 1 }'
}

# The request with the right token must still work. The EventSource pod may be restarting, so retry.
ok=0
for attempt in 1 2 3 4 5 6; do
  send "$tag-valid" "Bearer $token"
  for _ in $(seq 1 8); do
    if has "$tag-valid"; then ok=1; break; fi
    sleep 2
  done
  [ "$ok" = 1 ] && break
done
if [ "$ok" != 1 ]; then
  echo "FAIL: a request with the correct bearer token did not create an order- Workflow"
  exit 1
fi
echo "PASS: a request with the correct bearer token created a Workflow"

send "$tag-none"
send "$tag-wrong" "Bearer not-the-token"
send "$tag-nobearer" "$token"
sleep 25
fail=0
for suffix in none wrong nobearer; do
  if has "$tag-$suffix"; then
    echo "FAIL: a request with '$suffix' credentials created a Workflow"
    fail=1
  else
    echo "PASS: a request with '$suffix' credentials created no Workflow"
  fi
done
exit $fail
