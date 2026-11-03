# Question

Solve this question on: `terminal`

The operations team in `starfleet` wants alerts and acknowledgements from the outposts handled by one pipeline that keeps its events apart from every other workload. The namespace has no EventBus yet. Build the pipeline so that all of the following is true.

1. Create an EventBus named `signals` with the JetStream type, version `2.10.10` and `3` replicas. Each server pod must have its own `1Gi` volume claim. The stream of the bus must keep messages for at most `12h`, set through the stream configuration, so that the merged configuration in the status of the bus shows `maxAge` of `12h`. Do not create an EventBus named `default`.

2. Create a webhook EventSource named `beacon` that uses the bus `signals` and runs `2` pods. It has two events: `alert` (port `12000`, path `/alert`, method `POST`) and `ack` (port `12000`, path `/ack`, method `POST`). Expose them through a Service.

3. Create a Sensor named `escalate` that uses the bus `signals` and depends on both events. A request to `alert` creates a Workflow named `page-...` only when the JSON body has `level` equal to `critical`. Requests with any other level create nothing. A request to `ack` creates a Workflow named `close-...` and never a `page-` Workflow.

4. In both Workflows the first parameter, `site`, holds the value of the key `site` in the request body, for example `{"level":"critical","site":"outpost-4"}`. Both Workflows must finish with the phase `Succeeded`. One request must create exactly one Workflow.

Constraints: use the service account `event-trigger` for the Sensor and `workflow-runner` for the Workflows, and the image `docker.io/library/busybox:1.37` for the Workflow containers. The pod `shuttle` in `starfleet` has `curl`. The Service for the webhook is `beacon-eventsource-svc`. `kubectl` already points at the cluster as the cluster administrator.
