# Expression, Script And Time Filters In Practice

A data filter compares one path with a list of values. That is enough for a field that must equal a word or exceed a number, but it cannot express a rule that mixes two fields, such as "the temperature is above 80 and the sensor is the hull". The expression filter, the script filter and the time filter cover the cases that a data filter cannot. This part runs all three against real requests, so you can see which events each one admits.

The playground has the EventBus `default`. The EventSource, the Sensors and every request in this part are created by you.

## The events to filter

Save this as `eventsource-telemetry.yaml`. The EventSource has one webhook event named `reading`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: telemetry
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    reading:
      port: "12000"
      endpoint: /reading
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-telemetry.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/telemetry --timeout=180s
```

To keep the requests short, define a shell function that sends one reading from the pod `shuttle`. The arguments are the sensor name and the temperature:

```sh
send_reading() {
  kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"sensor\":\"$1\",\"temp\":$2}" http://telemetry-eventsource-svc:12000/reading
}
```

The function prints the status code. The EventSource answers `200` for every request, whatever the Sensor does with the event, because the filters run later in the Sensor.

## The expression filter

An expression filter has an `expr` and a list of `fields`. Each field gives a name to one path of the event data, and the expression uses the names. Save this as `sensor-hot-hull.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: hot-hull
  namespace: starfleet
spec:
  dependencies:
    - name: reading-dep
      eventSourceName: telemetry
      eventName: reading
      filters:
        exprs:
          - expr: temp > 80 && sensor == "hull"
            fields:
              - name: temp
                path: body.temp
              - name: sensor
                path: body.sensor
  triggers:
    - template:
        name: print-hot
        log: {}
```

Apply it and send three readings. Only the first one is a hot reading of the hull:

```sh
kubectl apply -f sensor-hot-hull.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/hot-hull --timeout=180s
kubectl -n starfleet get pods -l sensor-name=hot-hull
send_reading hull 95
send_reading hull 60
send_reading cabin 95
```

Repeat the `get pods` command until one pod is `Running` before you send the readings. Then read the log of the Sensor:

```sh
kubectl -n starfleet logs -l sensor-name=hot-hull --tail=20
```

The log trigger wrote one event: the reading with the sensor `hull` and the temperature `95`. The cool hull and the hot cabin did not pass, because the expression needs both conditions. The expression filter evaluates the types that JSON gives, so `temp` is a number and the comparison `> 80` is numeric.

## The script filter

The script filter is a Lua program. The Sensor gives it the event data as a table named `event`, and the program must return `true` for the event to pass. Use it when the rule needs a loop, a string function or several steps. Save this as `sensor-hot-hull-script.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: hot-hull-script
  namespace: starfleet
spec:
  dependencies:
    - name: reading-dep
      eventSourceName: telemetry
      eventName: reading
      filters:
        script: |-
          if event.body.sensor == "hull" and event.body.temp > 80 then
            return true
          end
          return false
  triggers:
    - template:
        name: print-hot
        log: {}
```

Apply it, wait for the new pod and send the same three readings:

```sh
kubectl apply -f sensor-hot-hull-script.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/hot-hull-script --timeout=180s
kubectl -n starfleet get pods -l sensor-name=hot-hull-script
send_reading hull 95
send_reading hull 60
send_reading cabin 95
kubectl -n starfleet logs -l sensor-name=hot-hull-script --tail=20
```

The result is the same as with the expression: only the hot hull reading passes. The two filters are equal here, so choose the simpler one. The expression filter is easier to read and cannot run an endless loop. The script filter is the tool for logic that an expression cannot hold.

## The time filter

The time filter admits events only inside a daily window. The `start` and `stop` are written as `HH:MM:SS` in UTC, and the filter compares them with the time of the event. To see it work without waiting for a particular hour, make a window of one second at midnight UTC. Save this as `sensor-night-only.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: night-only
  namespace: starfleet
spec:
  dependencies:
    - name: reading-dep
      eventSourceName: telemetry
      eventName: reading
      filters:
        time:
          start: "00:00:00"
          stop: "00:00:01"
  triggers:
    - template:
        name: print-night
        log: {}
```

Apply it, wait for the pod, print the current time in UTC and send a reading:

```sh
kubectl apply -f sensor-night-only.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/night-only --timeout=180s
kubectl -n starfleet get pods -l sensor-name=night-only
date -u +%H:%M:%S
send_reading hull 95
kubectl -n starfleet logs -l sensor-name=night-only --tail=20
```

Unless you sent the reading in the first second of the day, the Sensor dropped the event, and the log has no event line. The time filter looks at the time of the event and not at a state: it needs no memory and no schedule. A window such as `22:00:00` to `04:00:00` crosses midnight, and the filter handles that case.

## Filters on one dependency and the logical operator

A dependency can hold several types of filters. By default every configured type must pass. Add `filtersLogicalOperator: "or"` on the dependency, next to `filters`, to admit an event when any one type passes. Test this on the Sensor `night-only`, in which the time filter alone blocks the reading. Change the dependency in `sensor-night-only.yaml` so that it has an expression filter that the reading satisfies, and the operator `or`:

```yaml
      filtersLogicalOperator: "or"
      filters:
        exprs:
          - expr: temp > 80
            fields:
              - name: temp
                path: body.temp
        time:
          start: "00:00:00"
          stop: "00:00:01"
```

Apply the file again, wait for the new pod and send a hot reading:

```sh
kubectl apply -f sensor-night-only.yaml
kubectl -n starfleet get pods -l sensor-name=night-only
send_reading hull 95
kubectl -n starfleet logs -l sensor-name=night-only --tail=20
```

The log now has the event. With `and`, which is the default, the time filter would block every hot reading outside its window. With `or`, the hot reading passes through the expression filter, and the time filter no longer decides alone.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete sensor hot-hull hot-hull-script night-only
kubectl -n starfleet delete eventsource telemetry
```

This part used three filter types on one event stream and showed that each one admits a different set of events. A filter still looks at one event only. A rule that needs two events, such as "a hot reading and then a pressure drop", belongs to trigger conditions.

## Common pitfalls

> [!WARNING]
> - **A path without `body.` in an expression field.** The field finds nothing, the expression fails and the event is dropped.
> - **A script that does not end in `return true` or `return false`.** Only the boolean `true` passes an event.
> - **Writing the time window in local time.** The filter uses UTC.
> - **Sending events right after a change.** The controller replaces the Sensor pod, and events sent during the start are not seen by the new pod.
> - **Putting the logical operator inside `filters`.** `filtersLogicalOperator` sits on the dependency itself.
