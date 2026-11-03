# Question

Solve this question on: `terminal`

The launch team sends a request to the EventSource `fleet` in `starfleet` when a ship is ready, either from the scout dock or from the relay dock. Every ready ship must start one Workflow named `launch-...` that prints the name of the ship. The Sensor `launch` was built for this, but no Workflow ever appears. Fix the Sensor so that all of the following is true.

1. The EventSource `fleet` has the events `scout` (port `12000`, path `/scout`) and `relay` (port `13000`, path `/relay`). The Sensor `launch` depends on both. A request to either event, on its own, must create exactly one `launch-` Workflow.

2. The request body is JSON with the key `ship`, for example `{"ship":"aurora"}`. The Workflow parameter `ship` must hold that value, for requests to `scout` and for requests to `relay`. The Workflow currently prints `unset`.

3. The Workflows must finish with the phase `Succeeded`.

Constraints: do not change the EventBus, the EventSource `fleet`, the service accounts or the pods `shuttle` and `drifter`. Keep the Sensor name `launch`, its two dependencies, the Workflow name prefix `launch-`, the service account `event-trigger` for the Sensor and `workflow-runner` for the Workflow. The pod `shuttle` in `starfleet` has `curl`. The Service for the webhook is `fleet-eventsource-svc`. `kubectl` already points at the cluster as the cluster administrator.
