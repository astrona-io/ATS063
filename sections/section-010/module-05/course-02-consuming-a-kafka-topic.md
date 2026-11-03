# Consuming A Kafka Topic

A Kafka EventSource reads one topic and one partition and publishes each message as an event. This part creates one, sends messages with the producer tool inside the broker pod, and starts a Workflow for each message.

## The fields of the Kafka event

Each event under `spec.kafka` has these fields:

- `url` is the address of the broker, with the port and without a scheme, for example `kafka.starfleet.svc:9092`. A comma separated list names several brokers.
- `topic` is the topic to read.
- `partition` is the partition number, written as a string, for example `"0"`.
- `jsonBody` set to `true` embeds a JSON message as JSON.
- `consumerGroup` is optional. When it is set, the EventSource joins a consumer group, and the broker remembers the offset of the group.
- `connectionBackoff` sets retries when the connection fails.
- `version` sets the Kafka protocol version when the broker is old.

## Create the pipeline

Save this as `harbor-kafka.yaml`. The EventSource reads the topic `arrivals`, and the Sensor starts a Workflow with the ship name from the message:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: harbor-kafka
  namespace: starfleet
spec:
  kafka:
    arrival:
      url: kafka.starfleet.svc:9092
      topic: arrivals
      partition: "0"
      jsonBody: true
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: harbor-kafka
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: arrival-dep
      eventSourceName: harbor-kafka
      eventName: arrival
  triggers:
    - template:
        name: run-arrival
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: kafka-arrival-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                arguments:
                  parameters:
                    - name: ship
                      value: unset
                templates:
                  - name: report
                    inputs:
                      parameters:
                        - name: ship
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["arrival of {{inputs.parameters.ship}}"]
          parameters:
            - src:
                dependencyName: arrival-dep
                dataKey: body.ship
              dest: spec.arguments.parameters.0.value
```

<!-- astrona:playground:renew -->

Apply it and wait for both pods:

```sh
kubectl apply -f harbor-kafka.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=harbor-kafka --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=harbor-kafka --timeout=180s
```

## Send messages

Write the helper from the overview of the playground, or use the command directly. The producer tool reads lines from its input, and each line is one message:

```sh
echo '{"ship":"scout"}' | kubectl -n starfleet exec -i deploy/kafka -- /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka.starfleet.svc:9092 --topic arrivals
```

The topic `arrivals` did not exist. The broker creates a topic when a producer first writes to it, if automatic creation is on, which is the default. Wait a few seconds, then list the Workflows and read the value of the parameter:

```sh
kubectl -n starfleet get workflows
kubectl -n starfleet get workflows -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

A Workflow named `kafka-arrival-...` exists and its parameter is `scout`. If the Workflow does not appear, the topic may have been created after the EventSource connected. Read the log of the EventSource and send the message again:

```sh
kubectl -n starfleet logs -l eventsource-name=harbor-kafka --tail=20
```

## What the partition means

The EventSource above reads partition 0 of the topic. A topic created by automatic creation has one partition, so partition 0 holds every message. A topic with several partitions needs one event for each partition that you want to read, because one event reads one partition.

## What the consumer group changes

Without `consumerGroup`, the EventSource reads the partition directly and tracks its own position inside the pod. After a restart it does not know what it read before. With `consumerGroup`, the broker stores the offset of the group, so a restarted pod continues where the group stopped. Where a reader without an offset starts, at the beginning of the log or at its end, depends on the settings of the client, so test it with your broker before you depend on it.

## Clean up

```sh
kubectl -n starfleet delete -f harbor-kafka.yaml
```

## Common pitfalls

> [!WARNING]
> - **Writing `partition: 0` without quotes.** The field is a string, so write `"0"`.
> - **Reading only partition 0 of a topic with several partitions.** Messages in the other partitions are not read.
> - **Sending a message before the EventSource is ready.** A reader without an offset may start after the message.
> - **Using `bootstrap-server` with the pod IP.** Use the Service name, as the broker advertises it.
