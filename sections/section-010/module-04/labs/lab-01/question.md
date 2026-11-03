# Question

Solve this question on: `terminal`

The harbor radio publishes every arrival of a ship as a JSON message such as `{"ship":"scout"}` to the NATS subject `fleet.arrival`. The NATS server is the Service `nats` in `starfleet`. The EventSource `radio` has the NATS event `arrival`, and the Sensor `radio` should create a Workflow named `arrival-...` for every message, with the ship name in the Workflow parameter `ship`. No Workflow appears, and the ship name never arrives in a Workflow either.

Repair the EventSource `radio` so that:

1. The event `arrival` subscribes to the subject on which the radio publishes.
2. The event `arrival` carries the message as JSON, so that the Sensor can read the key `ship` of the message body.

Constraints: do not change the Sensor `radio`, the EventBus, the service accounts or the pods `nats`, `natsbox` and `shuttle`. Keep the event name `arrival` and the URL `nats://nats.starfleet.svc:4222`. The pod `natsbox` has the `nats` tool: `nats pub --server nats://nats.starfleet.svc:4222 <subject> <message>`. `kubectl` already points at the cluster as the cluster administrator.
