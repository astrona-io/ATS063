# Question

Solve this question on: `terminal`

The scout fleet in `starfleet` uses a calendar EventSource named `beacon` that produces one event named `tick` every 20 seconds. A Sensor named `beacon` creates a Workflow named `beacon-...` for each event. Someone changed the EventSource to two replicas with Kubernetes leader election, and since then no Workflow is created. Repair the setup so that it runs with high availability. All of the following must be true.

1. The EventSource `beacon` keeps `2` replicas and the leader election annotation `events.argoproj.io/leader-election: k8s`. Its pods must run with their own ServiceAccount: not `default`, not `event-trigger` and not `workflow-runner`. That ServiceAccount may `get`, `create` and `update` Leases in `starfleet`, and it must have no read access to pods, secrets or deployments.

2. One of the two EventSource pods holds the Lease `eventsource-beacon`. When that pod is deleted, the other pod takes over the Lease within two minutes, and the Deployment brings back a second pod.

3. The main container of the EventSource pods has the requests `cpu: 50m` and `memory: 64Mi` and the limits `cpu: 200m` and `memory: 128Mi`.

4. The Sensor `beacon` runs with `2` replicas and keeps the ServiceAccount `event-trigger`. Its main container has the requests `cpu: 50m` and `memory: 64Mi` and the limits `cpu: 200m` and `memory: 256Mi`.

5. The calendar events create a new `beacon-` Workflow, and the Workflow reaches the phase `Succeeded`.

Constraints: do not rename or delete the EventSource or the Sensor, and do not change the interval, the event name, the dependency or the trigger. Do not scale the generated Deployments by hand. Do not remove the leader election annotation. Do not create another EventBus. `kubectl` already points at the cluster as the cluster administrator.
