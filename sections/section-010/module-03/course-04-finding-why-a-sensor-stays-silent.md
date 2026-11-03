# Finding Why A Sensor Stays Silent

A Sensor that does nothing is the most common problem in a new pipeline, and it is also the hardest to see, because nothing fails. The Sensor is deployed, the pod runs and the log is empty. The reason is almost always a mismatch between names: the Sensor waits for an event that the EventSource never publishes under that name.

This part builds a Sensor with a wrong event name on purpose. It then follows a short list of checks, from the object that holds the names to the log of the Sensor pod, and repairs the Sensor.

## How a dependency finds its event

A dependency matches events with two names. The `eventSourceName` is the `metadata.name` of an EventSource in the same namespace. The `eventName` is the name of one event inside that EventSource, such as the key under `spec.webhook`. The EventBus uses both names to build the address of the event, so a Sensor receives a message only when both names are equal to the ones the EventSource publishes under.

The third name, `name` in the dependency, is local to the Sensor. Trigger conditions and parameters use it. It has no link to the other two names, so a correct `name` and a wrong `eventName` is possible, and the Sensor object looks healthy in both cases.

The Sensor controller does not look at the EventSources when it builds the Sensor. It cannot know whether an event with that name will ever exist, because an EventSource can be created later. A wrong name is therefore not an error in the status. It is a dependency that never receives anything.

## Build a Sensor with a wrong event name

Save this as `eventsource-probe-gw.yaml`. The EventSource has one event named `ping`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: probe-gw
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    ping:
      port: "12000"
      endpoint: /ping
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-probe-gw.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/probe-gw --timeout=180s
```

Save this Sensor as `sensor-probe-watch.yaml`. The event name in the dependency is `pong`, which does not exist:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: probe-watch
  namespace: starfleet
spec:
  dependencies:
    - name: ping-dep
      eventSourceName: probe-gw
      eventName: pong
  triggers:
    - template:
        name: print-ping
        log: {}
```

Apply it and send a request to the real event:

```sh
kubectl apply -f sensor-probe-watch.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/probe-watch --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"ship":"probe"}' http://probe-gw-eventsource-svc:12000/ping
```

The request returns `200`, because the EventSource accepted it. The Sensor is deployed too. The sections below follow the checks that find the fault.

## Check 1: did the EventSource accept the event

Start at the source. The log of the EventSource pod shows each event that it publishes to the bus:

```sh
kubectl -n starfleet logs -l eventsource-name=probe-gw --tail=10
```

The log has a line for the request on the event `ping`. This tells you that the first stage works and that the event is on the bus under the names `probe-gw` and `ping`. If the log had no line, the problem would be before the bus, for example a wrong port, path or method in the request.

## Check 2: does the dependency name the same event

Print the names that the Sensor waits for, next to the names that the EventSource publishes:

```sh
kubectl -n starfleet get sensor probe-watch -o jsonpath='{range .spec.dependencies[*]}{.eventSourceName}{" "}{.eventName}{"\n"}{end}'
kubectl -n starfleet get eventsource probe-gw -o jsonpath='{.spec.webhook}'
```

The Sensor waits for `probe-gw pong`. The EventSource has a webhook event named `ping`. The two names are different, which is the fault. Compare each name by eye, including the case of the letters, because names are case sensitive.

## Check 3: does the Sensor pod receive anything

The log of the Sensor pod confirms the diagnosis. A Sensor with a matching dependency logs each event that it receives. A Sensor with a wrong name logs nothing about the request:

```sh
kubectl -n starfleet logs -l sensor-name=probe-watch --tail=20
```

The log shows the start of the Sensor and its subscription to the bus. It has no line for the request, because the message of the event `ping` never matched the subscription for `pong`.

## Repair the Sensor and test again

Change `eventName` to `ping` in `sensor-probe-watch.yaml` and apply the file again:

```sh
kubectl apply -f sensor-probe-watch.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/probe-watch --timeout=180s
kubectl -n starfleet get pods -l sensor-name=probe-watch
```

The controller replaces the Sensor pod when a dependency changes. Repeat the last command until one pod is `Running`, because an event that you send while the new pod starts can be missed. Then send the request again and read the log:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"ship":"probe"}' http://probe-gw-eventsource-svc:12000/ping
kubectl -n starfleet logs -l sensor-name=probe-watch --tail=20
```

The log now has a line for the event, with the body `{"ship":"probe"}` in its data. The old request is not delivered again, so only a new request produces a line.

Delete the objects:

```sh
kubectl -n starfleet delete sensor probe-watch
kubectl -n starfleet delete eventsource probe-gw
```

## The order of the checks

The checks follow the direction of the event. First the EventSource log, which proves that the event was published. Then the names in the dependency, which prove that the Sensor asks for it. Then the Sensor log, which proves that it arrives. Only after those three, look at the trigger: its conditions, its parameters and the permission of the service account. A trigger problem shows an error line in the Sensor log, while a name problem shows no line at all. That difference tells you which half of the Sensor to inspect.

This part gave a fixed order for finding a silent Sensor. What remains open is a Sensor that does receive events but still does nothing, which filters and conditions can cause.

## Common pitfalls

> [!WARNING]
> - **Treating `Deployed` as proof that the Sensor works.** The condition only says that the controller built the pod. It says nothing about the names.
> - **Confusing the three names.** The `name` of a dependency is local to the Sensor. The `eventSourceName` and the `eventName` must equal what the EventSource publishes.
> - **Testing right after an edit.** The new pod needs time to start and subscribe, and an event sent in that time is lost for it.
> - **Looking at the trigger first.** A silent Sensor with no error line usually has a name or a filter problem, not a trigger problem.
