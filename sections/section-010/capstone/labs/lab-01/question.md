# Question

Solve this question on: `terminal`

The harbor office in `starfleet` wants every ship movement written to a log. Ships report an arrival or a departure with an HTTP request. Only requests that carry the office token may be accepted. The cluster already has an EventBus named `default` and a Secret named `harbor-token` with the key `token`. Build the pipeline so that all of the following is true.

1. Create a webhook EventSource named `harbor` with two events: `arrival` (port `12000`, path `/arrival`, method `POST`) and `departure` (port `12000`, path `/departure`, method `POST`). Expose them through a Service. Both events must require a bearer token that is read from the Secret `harbor-token`, key `token`.

2. Create a Sensor named `logbook` that depends on both events. A request to either event, on its own, must run the trigger exactly once.

3. The trigger creates a Workflow named `logbook-...`. The request body is JSON with the key `ship`, for example `{"ship":"aurora"}`. The first Workflow parameter, `ship`, must hold that value. The second Workflow parameter, `movement`, must hold the name of the event, `arrival` or `departure`, taken from the event itself. The Workflow must finish with the phase `Succeeded`.

4. A request without the `Authorization` header, with a wrong token or without the word `Bearer` must create no Workflow.

Constraints: do not change the EventBus or the Secret. Use the service account `event-trigger` for the Sensor and `workflow-runner` for the Workflow, and the image `docker.io/library/busybox:1.37` for the Workflow container. The pod `shuttle` in `starfleet` has `curl`. The Service for the webhook is `harbor-eventsource-svc`. `kubectl` already points at the cluster as the cluster administrator.
