# Question

Solve this question on: `terminal`

The dispatch team sends orders to the EventSource `dispatch` in `starfleet`. Every order request creates a Workflow named `order-...`. The endpoint is open to every pod in the cluster, and the team also wants a regular heartbeat. Make three changes.

1. The EventSource `dispatch` has the event `order` on port `12000`, path `/order`. Protect that event with a bearer token. The token is stored in the Secret `dispatch-token` under the key `token`. A request with the correct token must still create a Workflow. A request with no token, a wrong token, or a token without the word `Bearer` must create none. Do not change the Secret.

2. Create a second EventSource named `ticker` in `starfleet` with one calendar event named `beat`. It must fire at least once every 60 seconds.

3. Create a Sensor named `ticker` in `starfleet` that depends on the event `beat` of the EventSource `ticker`. On every event it must create an Argo Workflow with the name prefix `beat-`. The Sensor pod must run as the service account `event-trigger`, and the Workflow must run as `workflow-runner`. The Workflows must finish with the phase `Succeeded`.

Constraints: do not change the EventBus, the Sensor `dispatch`, the service accounts or the pods `shuttle` and `drifter`. The pod `shuttle` in `starfleet` has `curl`. The Service for the webhook is `dispatch-eventsource-svc`. `kubectl` already points at the cluster as the cluster administrator.
