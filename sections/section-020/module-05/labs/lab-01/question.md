# Question

Solve this question on: `terminal`

The webhook EventSource `fleet` in `starfleet` should receive a POST request on the endpoint `/report` and the Sensor `fleet` should then create a Workflow named `report-...`. A request to the Service `fleet-eventsource-svc` on port 12000 does not create any Workflow, and the EventSource has no pod.

Repair the pipeline so that:

1. The EventSource `fleet` is deployed on the EventBus that exists in `starfleet` and has one ready pod.
2. The dependency of the Sensor `fleet` receives the event of the EventSource.
3. The pod of the Sensor `fleet` runs as a service account that is allowed to create Workflows in `starfleet`.
4. A request sent from the pod `shuttle` creates a Workflow that succeeds.

Constraints: keep the names `fleet` and `report`, the port 12000 and the endpoint `/report`. Do not change the EventBus, the existing service accounts, their Roles or the pod `shuttle`. Use an existing service account for the Sensor. `kubectl` already points at the cluster as the cluster administrator.
