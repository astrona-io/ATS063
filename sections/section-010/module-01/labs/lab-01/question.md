# Question

Solve this question on: `terminal`

The starfleet operations team wants a mission report to start whenever the dispatch system sends a request. The `starfleet` namespace has Argo Workflows, Argo Events and a running EventBus named `default`. Nothing else is deployed. Build the pipeline that turns a webhook request into a Workflow.

1. Create an EventSource named `webhook` in `starfleet` with one webhook event named `mission`. It must listen on port `12000`, at the path `/mission`, and accept the method `POST`. It must also create the Service `webhook-eventsource-svc`, so that other pods can send requests to it by name.

2. Create a Sensor named `mission` in `starfleet`. It must depend on the event `mission` of the EventSource `webhook`. The Sensor pod must run as the service account `event-trigger`.

3. The Sensor must have one trigger that creates an Argo Workflow with the name prefix `mission-`. Each event must create a new Workflow. The Workflow must run as the service account `workflow-runner` and print the text from the field `message` of the JSON request body. The Workflow must finish with the phase `Succeeded`.

Constraints: do not change the EventBus, the service accounts or the pods `shuttle` and `drifter`. The pod `shuttle` in `starfleet` has `curl` and can be used to send test requests. `kubectl` already points at the cluster as the cluster administrator.
