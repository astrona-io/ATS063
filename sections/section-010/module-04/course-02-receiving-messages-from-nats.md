# Receiving Messages From NATS

Many systems already publish their events to a message broker. Instead of asking each of them to call a webhook, an EventSource can subscribe to the broker and turn each message into an event. NATS is a small broker with subjects: a publisher sends a message to a subject name, and every subscriber of that subject receives a copy. The NATS EventSource is a subscriber.

This part uses a NATS server that is already running in the playground. You create the EventSource, publish messages from a client pod and read the events in a Sensor. You also see what happens to a message that is not JSON, and what `connectionBackoff` does when the server is not available.

## The server and the client

The playground has a pod `nats` with a Service `nats` in the namespace `starfleet`. Clients reach the server at `nats://nats.starfleet.svc:4222`. The pod `natsbox` has the `nats` command-line tool, which publishes messages. Confirm that both pods run:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get pods nats natsbox
```

Both pods show `Running`. The server needs no password in the playground, so the EventSource needs no Secret.

## Create the NATS EventSource

A NATS event has a `url`, a `subject` and a few optional settings. The `subject` is the name that the EventSource subscribes to. The `jsonBody` field says that the message is JSON, so the EventSource embeds it as JSON in the event instead of as encoded text. The `connectionBackoff` field says how often to retry the connection and how the wait grows.

Save this as `eventsource-radio.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: radio
  namespace: starfleet
spec:
  nats:
    arrival:
      url: nats://nats.starfleet.svc:4222
      subject: fleet.arrival
      jsonBody: true
      connectionBackoff:
        duration: 5s
        steps: 5
        factor: 2
        jitter: 0.2
```

The event is named `arrival`. The EventSource does not open a port, so it has no `service`. Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-radio.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/radio --timeout=180s
```

## Read the events in a Sensor

Save this Sensor as `sensor-radio-log.yaml`. It logs each event that the EventSource publishes:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: radio-log
  namespace: starfleet
spec:
  dependencies:
    - name: arrival-dep
      eventSourceName: radio
      eventName: arrival
  triggers:
    - template:
        name: print-arrival
        log: {}
```

Apply it:

```sh
kubectl apply -f sensor-radio-log.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/radio-log --timeout=180s
kubectl -n starfleet get pods -l sensor-name=radio-log
```

Wait until the Sensor pod is `Running`. Publish a message from `natsbox` to the subject and read the log:

```sh
kubectl -n starfleet exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 fleet.arrival '{"ship":"scout"}'
kubectl -n starfleet logs -l sensor-name=radio-log --tail=20
```

The log has an event whose body holds `{"ship":"scout"}`. The data of a NATS event has the fields `subject`, which is the NATS subject, and `body`, which is the message. A Sensor reads the ship with the path `body.ship`, the same way it reads a webhook body. The event context has the type `nats`, the source `radio` and the subject `arrival`. The subject of the context is the event name, not the NATS subject, so do not mix them.

## What jsonBody changes

With `jsonBody: true`, a message that is not valid JSON cannot be embedded. Publish one and look at the log of the EventSource:

```sh
kubectl -n starfleet exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 fleet.arrival 'not json'
kubectl -n starfleet logs -l eventsource-name=radio --tail=10
```

The EventSource logs a problem with the message, and the Sensor log gets no new event. Without `jsonBody`, the EventSource accepts any message and carries the bytes in the `body` field in encoded form. Set `jsonBody: true` only when the publisher always sends JSON, so that Sensors can use paths into the body.

## Messages that arrive while the EventSource is down

A plain NATS subscription is not durable. NATS delivers a message only to subscribers that are connected at that moment. While the EventSource pod restarts, for example after a change of its spec, the messages that are published are lost. The subject does not keep them. Brokers with persistent logs, such as Kafka, behave differently, because the consumer group remembers its position.

The `connectionBackoff` field helps with a different problem: the server is not reachable when the EventSource starts. The EventSource retries with the wait `duration`, multiplied by `factor` after each step, up to `steps` times, and the `jitter` adds a small random part to each wait. If the server is still unreachable after the last step, the EventSource gives up and reports an error.

## One active pod

A NATS EventSource is a subscription type, so only one pod is active. With `replicas: 2`, the second pod waits. This avoids two subscribers receiving the same message and publishing the event twice. The leader election needs a service account that can use Leases, as in the high availability of the calendar type.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete sensor radio-log
kubectl -n starfleet delete eventsource radio
```

This part showed one subscription type from the setup to the event in a Sensor, with the delivery limit of a plain subject. The open question is how the same approach works for services outside the cluster, where the credentials come from Secrets.

## Common pitfalls

> [!WARNING]
> - **Confusing the NATS subject with the event name.** The subject belongs to NATS, and the event name is what a Sensor depends on.
> - **Setting `jsonBody: true` for text messages.** The messages are not accepted as events.
> - **Expecting messages to wait during a restart.** A plain subject does not keep them.
> - **Pointing `url` at a Service in another namespace without its full name.** Use `<service>.<namespace>.svc`.
> - **Running two replicas to double the speed.** The second pod is a standby, not a second worker.
