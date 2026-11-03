#!/usr/bin/env bash
set -uo pipefail
NS=starfleet
fail=0
pass() { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

if ! kubectl -n "$NS" get eventsource ticker >/dev/null 2>&1; then
  echo "FAIL: EventSource ticker not found in $NS"
  exit 1
fi
pass "EventSource ticker exists"

interval=$(kubectl -n "$NS" get eventsource ticker -o jsonpath='{.spec.calendar.beat.interval}' 2>/dev/null)
schedule=$(kubectl -n "$NS" get eventsource ticker -o jsonpath='{.spec.calendar.beat.schedule}' 2>/dev/null)
if [ -n "$interval" ] && [ -n "$schedule" ]; then
  bad "event beat must set interval or schedule, not both"
elif [ -n "$interval" ]; then
  case "$interval" in
    *s) secs="${interval%s}" ;;
    *m) secs=$(( ${interval%m} * 60 )) ;;
    *) secs=999999 ;;
  esac
  case "$secs" in
    ''|*[!0-9]*) bad "interval '$interval' is not a plain number of seconds or minutes" ;;
    *) if [ "$secs" -ge 1 ] && [ "$secs" -le 60 ]; then pass "event beat fires every $interval"; else bad "interval must be 60 seconds or less (got '$interval')"; fi ;;
  esac
elif [ "$schedule" = "* * * * *" ]; then
  pass "event beat fires every minute by schedule"
else
  bad "event beat needs interval 60s or less, or the schedule '* * * * *' (got interval '$interval', schedule '$schedule')"
fi

deployed=$(kubectl -n "$NS" get eventsource ticker -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null)
[ "$deployed" = "True" ] && pass "EventSource ticker is deployed" || bad "EventSource ticker condition Deployed is '$deployed', expected True"

exit $fail
