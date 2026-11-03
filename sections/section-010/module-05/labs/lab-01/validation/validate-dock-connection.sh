#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

url=$(kubectl -n "$NS" get eventsource dock -o jsonpath='{.spec.kafka.arrival.url}' 2>/dev/null)
topic=$(kubectl -n "$NS" get eventsource dock -o jsonpath='{.spec.kafka.arrival.topic}' 2>/dev/null)
part=$(kubectl -n "$NS" get eventsource dock -o jsonpath='{.spec.kafka.arrival.partition}' 2>/dev/null)
[ "$url" = "kafka.starfleet.svc:9092" ] && pass "event arrival connects to kafka.starfleet.svc:9092" || bad "event arrival must use the url kafka.starfleet.svc:9092 (got '$url')"
[ "$topic" = "arrivals" ] && pass "event arrival reads the topic arrivals" || bad "event arrival must read the topic arrivals (got '$topic')"
[ "$part" = "0" ] && pass "event arrival keeps the partition 0" || bad "event arrival must keep the partition \"0\" (got '$part')"
deployed=$(kubectl -n "$NS" get eventsource dock -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource dock is deployed" || bad "EventSource dock condition Deployed is '$deployed', expected True"
exit $fail
