# Kafka And AMQP Compared

A webhook EventSource waits for a sender to call it. A Kafka or AMQP EventSource does the opposite: its pod opens a connection to the broker and reads. This changes what you need to set up, what you can lose, and how you run the pod more than once.

## Two models of a broker

Kafka stores messages in topics. A topic is split into partitions, and each partition is an ordered log. A reader keeps its own position in the log, called an offset, so a message stays in the log after it is read. Several readers can read the same messages independently.

AMQP, as used by RabbitMQ, routes messages. A publisher sends a message to an exchange. The exchange puts it in zero or more queues according to a routing rule. A consumer takes messages from a queue, and the broker removes a message from the queue when the consumer acknowledges it.

## What an EventSource needs for each

Both types are subscription types. The pod connects out, so no Service and no route from the sender are needed. The pod needs three things:

- A network path to the broker from the namespace of the EventSource, and a name that resolves, for example `kafka.starfleet.svc:9092`.
- The location to read from: a topic and a partition for Kafka, an exchange, an exchange type and a routing key for AMQP.
- Credentials, if the broker requires them. They are references to keys of a Secret in the namespace of the EventSource.

Both types have `jsonBody`, which embeds a JSON message as JSON so that a Sensor can use a path such as `body.ship`. Both have `connectionBackoff`, which sets how the pod retries when the connection fails.

## High availability

Because the pod reads from a broker, two active pods would read and publish the same message twice. For this reason these types are active-passive: with `replicas: 2` one pod serves and the other waits. The election runs through the EventBus unless you use the Lease annotation, as the high availability module explained.

## Look at the brokers

<!-- astrona:playground:renew -->

Both brokers are started by the playground. Check them:

```sh
kubectl -n starfleet get deployment kafka
kubectl -n starfleet get pod rabbitmq
kubectl -n starfleet get svc kafka rabbitmq
```

Both pods are `Running` and ready. List the topics of Kafka from inside its pod. A fresh broker has none that you created:

```sh
kubectl -n starfleet exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka.starfleet.svc:9092 --list
```

Ask the management API of RabbitMQ for its exchanges. The API uses the user `fleet`:

```sh
kubectl -n starfleet exec shuttle -- curl -s -u fleet:orbit-pass http://rabbitmq.starfleet.svc:15672/api/exchanges
```

The reply is JSON that lists the default exchanges of the broker. The EventSource in the next parts creates its own exchange when it connects.

## Choosing between the two

| Question | Kafka | AMQP |
| --- | --- | --- |
| What does the broker keep? | The log, until its retention ends | A queue entry, until it is acknowledged |
| Who tracks the position? | The reader, as an offset | The broker, with acknowledgements |
| Fan out to many readers | Each reader has its own offset | Each reader needs its own queue |
| Replay old messages | Possible by reading from an earlier offset | Not possible once acknowledged |

The EventSource does not change these properties. It is one more reader, and what it receives depends on the broker.

## Common pitfalls

> [!WARNING]
> - **Adding a Service for a Kafka or AMQP EventSource.** The pod connects out, so a Service receives nothing.
> - **Using the address `localhost` or the pod IP of the broker.** Use the Service name, which stays the same when the pod is replaced.
> - **Putting the password into the `url`.** Use the credential fields that reference a Secret.
> - **Expecting two active pods.** These types run one active pod, and the others wait.
