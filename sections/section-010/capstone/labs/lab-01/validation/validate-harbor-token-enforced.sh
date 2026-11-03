#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
token=$(kubectl -n "$NS" get secret harbor-token -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode 2>/dev/null)
tag="cap-$(date +%s)-$RANDOM"

send() { # path, ship, optional authorization header value
  if [ -n "${3:-}" ]; then
    kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
      -H 'Content-Type: application/json' -H "Authorization: $3" \
      -d "{\"ship\":\"$2\"}" "http://harbor-eventsource-svc:12000/$1" >/dev/null 2>&1
  else
    kubectl -n "$NS" exec shuttle -- curl -s -o /dev/null --max-time 10 -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"ship\":\"$2\"}" "http://harbor-eventsource-svc:12000/$1" >/dev/null 2>&1
  fi
}
has() {
  kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[*].value}{"\n"}{end}' 2>/dev/null |
    awk -F'\t' -v m="$1" '$1 ~ /^logbook-/ && index($2, m) { found=1 } END { exit found ? 0 : 1 }'
}

ok=0
for attempt in 1 2 3 4 5 6; do
  send arrival "$tag-valid" "Bearer $token"
  for _ in $(seq 1 8); do
    if has "$tag-valid"; then ok=1; break; fi
    sleep 2
  done
  [ "$ok" = 1 ] && break
done
if [ "$ok" != 1 ]; then
  echo "FAIL: a request with the correct bearer token did not create a logbook- Workflow"
  exit 1
fi
echo "PASS: a request with the correct bearer token created a Workflow"

for ev in arrival departure; do
  send "$ev" "$tag-none-$ev"
  send "$ev" "$tag-wrong-$ev" "Bearer not-the-token"
  send "$ev" "$tag-nobearer-$ev" "$token"
done
sleep 25
fail=0
for ev in arrival departure; do
  for kind in none wrong nobearer; do
    if has "$tag-$kind-$ev"; then
      echo "FAIL: a request to $ev with '$kind' credentials created a Workflow"
      fail=1
    else
      echo "PASS: a request to $ev with '$kind' credentials created no Workflow"
    fi
  done
done
exit $fail
