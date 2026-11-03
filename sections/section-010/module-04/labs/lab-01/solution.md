# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-04/labs/lab-01
```

Look at the starting state. The EventSource has the event `arrival` and no `jsonBody`, and the subject has a typing mistake:

```sh
kubectl -n starfleet get eventsource radio -o yaml
kubectl -n starfleet get sensor radio -o yaml
```

## Step 1: Correct the subject

The radio publishes to `fleet.arrival`, and the EventSource subscribes to `fleet.arivals`. A NATS subscriber receives only messages for the subject it names, so nothing reaches the EventSource. Save the corrected EventSource as `radio.yaml`. It also sets `jsonBody`, which is the second step:

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
```

## Step 2: Embed the message as JSON

Without `jsonBody: true`, the EventSource carries the bytes of the message in encoded form. The Sensor reads `body.ship`, and that path does not exist in encoded bytes, so the parameter keeps its default `unset`. With `jsonBody: true`, the body is JSON and the path works.

Apply the file and wait for the controller to replace the pod:

```sh
kubectl apply -f radio.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/radio --timeout=180s
kubectl -n starfleet get pods -l eventsource-name=radio
```

Repeat the last command until only one pod is listed and it is `Running`. Then publish a message and look at the Workflows:

```sh
kubectl -n starfleet exec natsbox -- nats pub --server nats://nats.starfleet.svc:4222 fleet.arrival '{"ship":"scout"}'
kubectl -n starfleet get workflows
```

A Workflow named `arrival-...` appears. Check its argument:

```sh
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

The value is `scout`. Submit:

```sh
astrona submit
```

All checks pass.

## Why this works

A NATS EventSource is a subscriber, so the subject decides which messages it sees, and a wrong subject gives a silent EventSource without any error. The setting `jsonBody` decides whether the Sensor can address fields of the message. The Sensor needed no change, because it already used the right dependency and the right path.
