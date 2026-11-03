# Question

Solve this question on: `terminal`

The outpost beacon in `starfleet` publishes two webhook events: `dock` on port `12000` with the path `/dock`, and `clearance` on port `13000` with the path `/clearance`. The Sensor `gatekeeper` should start one Workflow named `admit-...` for each ship that is allowed to dock, but at the moment it starts none. Repair the Sensor. All of the following must be true.

1. A docking request is accepted only when the class in the request body is exactly `scout` and the fuel in the body is at least `20`. A fuel of exactly `20` is accepted. A fuel of `19`, a class of `freighter` and a class of `scoutship` are dropped.

2. A clearance is accepted only when the code in the body is exactly `granted`.

3. The trigger `admit` runs only when both a docking request and a clearance have arrived, in either order. Each pair starts exactly one Workflow, and one event alone starts nothing.

4. The first Workflow parameter, `ship`, holds the ship name from the request body in capitals. A request with the ship `drifter-7` gives the value `DRIFTER-7`. The Workflow must reach the phase `Succeeded`.

Constraints: keep the Sensor name `gatekeeper` and both of its dependencies. Do not change the EventSource `beacon` and do not create another Sensor. The pod `shuttle` in `starfleet` has `curl`, and the Service for the webhook is `beacon-eventsource-svc`. After you change the Sensor, wait for the new Sensor pod to be ready and give it about ten seconds before you send test events. `kubectl` already points at the cluster as the cluster administrator.
