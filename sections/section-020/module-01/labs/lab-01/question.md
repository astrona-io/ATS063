# Question

Solve this question on: `terminal`

The ledger team in `starfleet` wants its events kept apart from everything else and kept across restarts. The namespace has no EventBus yet. Build a dedicated bus and run a small pipeline through it. All of the following must be true.

1. Create an EventBus named `audit` in `starfleet` with the JetStream type, version `2.10.10` and `3` replicas. Each server pod must have its own `1Gi` volume claim, and the bus must be `Deployed`.

2. The stream of the bus keeps messages for at most `24h` and at most `1000` messages. Set this with the stream configuration of the bus, so that the merged configuration in the status of the bus shows `maxAge` of `24h` and `maxMsgs` of `1000`.

3. Create a webhook EventSource named `ledger` with one event named `entry` on port `12000` and the path `/entry` (method `POST`), exposed through a Service. Create a Sensor named `ledger` with one dependency on that event. Both objects must use the bus `audit`.

4. The Sensor creates a Workflow named `ledger-...` for each event. The first Workflow parameter, `message`, must hold the value of the key `message` in the JSON body of the request. The Workflow must finish with the phase `Succeeded`.

Constraints: do not create an EventBus named `default`. Use the service account `event-trigger` for the Sensor and `workflow-runner` for the Workflow, and the image `docker.io/library/busybox:1.37` for the Workflow container. The pod `shuttle` in `starfleet` has `curl`. The Service for the webhook is `ledger-eventsource-svc`. `kubectl` already points at the cluster as the cluster administrator.
