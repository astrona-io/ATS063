# Several Types In One EventSource

An EventSource can hold events of more than one type. A service might receive requests, send a heartbeat and listen to a queue, and keeping them in one object gives one pod, one set of settings and one name for the Sensors to depend on. It also couples them: they restart together, they share one template and they share one set of event names.

This part builds one EventSource with a webhook event, a calendar event and a NATS event. It shows how the event names work, what the controller builds for it and what a Sensor can depend on.

## Types are sibling fields

The types sit next to each other under `spec`. Each type has its own map of events. The name of an event must be unique across the whole EventSource, because a Sensor addresses an event by the EventSource name and the event name only, not by the type. The settings in `spec` outside the types, such as `eventBusName`, `replicas`, `template` and `service`, apply to the whole EventSource.

The controller builds one Deployment for the EventSource, and every type runs inside that one pod. The service needs a port for each webhook-type event that the EventSource contains.

## Create the combined EventSource

Save this as `eventsource-station.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: station
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    dock:
      port: "12000"
      endpoint: /dock
      method: POST
  calendar:
    pulse:
      interval: 20s
  nats:
    beacon:
      url: nats://nats.starfleet.svc:4222
      subject: station.beacon
      jsonBody: true
```

<!-- astrona:playground:renew -->

The EventSource has three events: `dock` of type webhook, `pulse` of type calendar and `beacon` of type NATS. Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-station.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/station --timeout=180s
kubectl -n starfleet get pods -l eventsource-name=station
```

One pod is listed. Wait until it is `Running`. All three events run in this pod.

## Depend on events of different types

A Sensor can depend on any combination of these events. Save this Sensor as `sensor-station-log.yaml`. It depends on all three events and runs the log trigger for each one on its own, using the condition field of each trigger:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: station-log
  namespace: starfleet
spec:
  dependencies:
    - name: dock
      eventSourceName: station
      eventName: dock
    - name: pulse
      eventSourceName: station
      eventName: pulse
    - name: beacon
      eventSourceName: station
      eventName: beacon
  triggers:
    - template:
        name: on-dock
        conditions: "dock"
        log: {}
    - template:
        name: on-pulse
        conditions: "pulse"
        log: {}
    - template:
        name: on-beacon
        conditions: "beacon"
        log: {}
```

Apply it and wait for the Sensor pod:

```sh
kubectl apply -f sensor-station-log.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/station-log --timeout=180s
kubectl -n starfleet get pods -l sensor-name=station-log
```

Send one event of each kind. The calendar event arrives by itself every twenty seconds:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' -d '{"ship":"scout"}' http://station-eventsource-svc:12000/dock
kubectl -n starfleet exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 station.beacon '{"status":"ok"}'
kubectl -n starfleet logs -l sensor-name=station-log --tail=30
```

The log shows events from three types. The context of each one tells them apart: the `type` is `webhook`, `calendar` or `nats`, the `source` is `station` for all of them, and the `subject` is the event name `dock`, `pulse` or `beacon`. Because the conditions name one dependency each, every trigger runs for its own event only. Without the conditions, the default rule is an AND of all dependencies, and no trigger would run until all three events had arrived.

## Why not one EventSource for everything

The coupling has a cost. A change to any event makes the controller replace the pod, so the webhook is interrupted when you edit the calendar. A failure in one type can stop the pod, and the other types stop with it. The pod runs with one service account, so the type with the most permissions decides the permissions of all of them. The high availability model is also one for the whole object: an EventSource with a calendar type runs one active pod, even if the webhook alone could run several active pods.

A good rule is to put events in one EventSource when they belong to one system and change together, and to separate them when they have different owners, different permissions or different availability needs.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete sensor station-log
kubectl -n starfleet delete eventsource station
```

This part showed that types are siblings in one object and that event names are the shared address space. The consequences are shared pods, shared permissions and one high availability model.

## Common pitfalls

> [!WARNING]
> - **Reusing an event name in two types.** Names must be unique across the EventSource.
> - **Mixing owners in one EventSource.** One team's edit restarts the other team's events.
> - **Forgetting the conditions in a Sensor with several dependencies.** The default rule needs all of them, so nothing runs.
> - **Expecting the webhook to scale out.** A calendar or NATS event in the same object makes the pod active-passive.
> - **Giving the pod one service account with all permissions.** The least-privileged design uses separate EventSources.
