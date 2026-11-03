# Question

Solve this question on: `terminal`

A producer writes each arrival of a ship to the Kafka topic `arrivals` as a JSON message such as `{"ship":"scout"}`. The broker is the Service `kafka` in `starfleet`, and it listens for clients on port 9092. The EventSource `dock` has the Kafka event `arrival`, and the Sensor `dock` should create a Workflow named `dock-...` for every message, with the ship name in the Workflow parameter `ship`. No Workflow appears.

Repair the EventSource `dock` so that:

1. The event `arrival` connects to the Service `kafka` on its client port.
2. The event `arrival` reads the topic on which the producer writes.
3. The event `arrival` carries the message as JSON, so that the Sensor can read the key `ship` of the message body.

Constraints: do not change the Sensor `dock`, the EventBus, the service accounts or the broker. Keep the event name `arrival` and the partition `"0"`. To produce a message, run this inside the Deployment `kafka`: `kubectl -n starfleet exec -i deploy/kafka -- /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka.starfleet.svc:9092 --topic arrivals`, and type or pipe one line. `kubectl` already points at the cluster as the cluster administrator.
