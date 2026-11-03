# Solution

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-05/labs/lab-01
```

Look at the starting state and at the log of the EventSource:

```sh
kubectl -n starfleet get eventsource dock -o yaml
kubectl -n starfleet get svc kafka
kubectl -n starfleet logs -l eventsource-name=dock --tail=20
```

The Service `kafka` exposes the port 9092. The EventSource uses the port 9093, which the Service does not expose, so the log shows a connection error.

## Step 1: Correct the port and the topic

The producer writes to `arrivals`, and the EventSource reads `arivals`. Save the corrected EventSource as `dock.yaml`. It also sets `jsonBody`, which is the second fault:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: dock
  namespace: starfleet
spec:
  kafka:
    arrival:
      url: kafka.starfleet.svc:9092
      topic: arrivals
      partition: "0"
      jsonBody: true
```

## Step 2: Embed the message as JSON

Without `jsonBody: true`, the Sensor path `body.ship` does not exist, and the parameter keeps its default `unset`. With the setting, the body is JSON and the path works.

Apply the file and wait for the controller to replace the pod:

```sh
kubectl apply -f dock.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/dock --timeout=180s
kubectl -n starfleet get pods -l eventsource-name=dock
```

Repeat the last command until only one pod is listed and it is `Running`. Then produce a message and look at the Workflows:

```sh
echo '{"ship":"scout"}' | kubectl -n starfleet exec -i deploy/kafka -- /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka.starfleet.svc:9092 --topic arrivals
kubectl -n starfleet get workflows
```

A Workflow named `dock-...` appears. Check its argument:

```sh
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

The value is `scout`. Submit:

```sh
astrona submit
```

All checks pass.

## Why this works

A Kafka EventSource is a client of the broker. The address decides whether it connects, the topic decides what it reads, and `jsonBody` decides whether the Sensor can address fields of the message. The Sensor needed no change.
