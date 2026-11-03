# Summary

Four identities act in a pipeline: the controller, the EventSource pod, the Sensor pod and the Workflow pods. The Sensor runs its trigger with the service account in `spec.template.serviceAccountName`, or with `default` when the field is empty. A Sensor without the right to create its target is `Deployed` and its pod is `Running`, and the failure is a `Forbidden` line in its log. `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<name>` tests an identity, and `--list` shows all its rights in a namespace. Give a Sensor only the verbs its trigger uses.

The controller, the EventSource pods and the Sensor pods each log, and the controller serves Prometheus metrics on port 7777 at `/metrics`. Logs are selected with the labels `eventsource-name` and `sensor-name`. The environment variable `LOG_LEVEL` in the container of the template sets the log level, and `debug` is for short searches only. Print the metrics page of your version before you rely on a metric name.

A webhook EventSource is reachable by every pod of the cluster through the Service `<name>-eventsource-svc`, and from other namespaces through `<name>-eventsource-svc.<namespace>.svc`. A NetworkPolicy narrows who can reach the pods, but it works only if the network plugin enforces it. A policy on an EventSource or a Sensor must allow the bus on port 4222, the API server for a Sensor, and DNS. An Ingress or a Gateway route is created by you, not by Argo Events, and it needs TLS and authentication of the sender.

Follow an event from the sender to the Workflow and stop at the first broken step: the status of the objects, the pods, the entry through the Service, the EventSource log, the Sensor log, the trigger and the target. A missing bus gives an EventSource without a pod. A wrong `eventName` gives a Sensor that logs no event. A missing identity gives `Forbidden` in the Sensor log.

Key facts:

- The Service of an EventSource is `<name>-eventsource-svc`, and it exists only when `spec.service` is set.
- The pods carry the labels `eventsource-name` and `sensor-name`.
- A dependency matches on `eventSourceName` and `eventName` together.
- A pod that no NetworkPolicy selects accepts all traffic.

<!-- astrona:playground:destroy -->
