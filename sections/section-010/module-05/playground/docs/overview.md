# Overview: Kafka And AMQP EventSources (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows and Argo Events installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events`, installed for the whole cluster, and Argo Workflows v3.7.3 in `argo`.
- In `starfleet`: an EventBus named `default` with three replicas, the pod `shuttle` (with `curl`), the Deployment `kafka` (Apache Kafka 3.9.0, one node, Service `kafka` on port 9092) and `rabbitmq` (RabbitMQ 4.0.5 with the management plugin, Service `rabbitmq` on ports 5672 and 15672), the Secret `rabbit-auth` with the RabbitMQ user, and the service accounts `event-trigger` and `workflow-runner`.
- No EventSource and no Sensor exists.

## Helpers

```sh
kpub() { echo "$2" | kubectl -n starfleet exec -i deploy/kafka -- /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka.starfleet.svc:9092 --topic "$1"; }
rpub() {
  kubectl -n starfleet exec shuttle -- curl -s -u fleet:orbit-pass -H 'content-type: application/json' \
    -X POST "http://rabbitmq.starfleet.svc:15672/api/exchanges/%2F/$1/publish" \
    -d "{\"properties\":{},\"routing_key\":\"$2\",\"payload\":$(printf '%s' "$3" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))'),\"payload_encoding\":\"string\"}"
}
```

`kpub arrivals '{"ship":"scout"}'` writes one message to the Kafka topic `arrivals`. `rpub fleet arrival '{"ship":"scout"}'` publishes to the exchange `fleet` of RabbitMQ.

## Practice tasks

- List the topics of the broker with `/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka.starfleet.svc:9092 --list` inside the pod `kafka`.
- Create a Kafka EventSource and a Sensor that starts a Workflow for each message, and send a message.
- Create an AMQP EventSource with the credentials from `rabbit-auth` and send a message through the management API.
- Delete the pod `kafka`, read the log of the EventSource, apply `kafka.yaml` again and send another message.
- Use a topic name with a typing mistake and find out what the EventSource log shows.
