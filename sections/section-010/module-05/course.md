# Kafka And AMQP EventSources

Many organisations already move events through a message broker. An Argo Events EventSource can connect to that broker as a client, read the messages and turn each one into an event for the Sensors. This module works with two brokers: Apache Kafka, which keeps an ordered log of messages in topics, and RabbitMQ, which routes messages with the AMQP protocol through exchanges and queues. You run both in the playground, connect an EventSource to each, and learn what happens when a broker is not available.

## Learning objectives

After this module you can:

- Explain how Kafka and AMQP EventSources differ from request-driven EventSources, and why they need no Service.
- Write a Kafka EventSource with the fields `url`, `topic`, `partition` and `jsonBody`, and send a message to it.
- Explain what `consumerGroup` changes for a Kafka EventSource.
- Write an AMQP EventSource with an exchange, a routing key and credentials from a Secret.
- Publish to a Kafka topic with the tools inside the broker pod and to a RabbitMQ exchange with its management API.
- Read the log of an EventSource to find a broker that is down, a wrong topic and a wrong credential.

## Before you start

You can create an EventSource and a Sensor, and you know the difference between an event and a message. The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas, ready before you start |
| `starfleet` | Deployment `kafka` and Service `kafka` | A single-node Kafka broker on port 9092 |
| `starfleet` | pod `rabbitmq` and Service `rabbitmq` | RabbitMQ with the management plugin, ports 5672 and 15672 |
| `starfleet` | Secret `rabbit-auth` | The RabbitMQ user `fleet` and its password |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

The module has four parts. The first part compares the two brokers and the way an EventSource connects to them. The second part consumes a Kafka topic. The third part consumes from RabbitMQ. The fourth part breaks the connection on purpose and reads the signs.

## How the module is built

Each part starts with a problem that you can see in the playground, and then explains the mechanism behind it. The commands create objects in the namespace `starfleet`, and each part deletes what it created. The module ends with a lab in which a Kafka EventSource receives nothing and you find out why.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
