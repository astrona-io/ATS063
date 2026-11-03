# Summary

An EventSource decides what counts as an event. The three types in this module cover the three ways an event can start: a caller sends a request, time passes, or an object in the cluster changes.

A webhook EventSource holds one or more named events, and each event is an HTTP listener with a port, a path and a method. The EventSource name and the event name together form the address that a Sensor depends on, and an event name can be used only once in one EventSource. The controller adds a `/health` endpoint on every port. The Service from `spec.service` is created for testing, and real exposure uses a Service of your own with the selector `eventsource-name`. The `authSecret` field makes one event require a bearer token that is read from a Secret. The token protects the event, not the transport.

A calendar EventSource produces events from time. An event uses either an interval or a cron schedule. The time zone and the excluded dates refine a schedule, and static metadata is added to the data of every event. The data of a calendar event is the time and the metadata, with no request body. Events during a restart are lost unless persistence with catch-up is configured.

A resource EventSource watches Kubernetes objects through the API server. The data holds the change type, the whole object, and the group, version and resource. The event types list is required. The label, field, prefix and start-time filters narrow the watch, and the filters on labels and fields are applied by the API server. The EventSource pod needs permission to get, list and watch the resource it watches.

The log trigger prints the data and the context of every event that a Sensor receives. It needs no permission and shows exactly what a trigger parameter can read.

Key facts:

- The data of a webhook event has `header` and `body`. The data of a calendar event has `eventTime` and `metadata`. The data of a resource event has `type`, `body`, `group`, `version` and `resource`.
- Webhook EventSources can run as several active pods. Calendar and resource EventSources run as one active pod with standby pods.
- A change of an EventSource makes the controller replace its pod, so test only after the new pod is ready.

A webhook event serves HTTPS when it has both `serverCertSecret` and `serverKeySecret`, and each field names a key in a Secret. The certificate must name the Service in its subject alternative name list, and a plain HTTP request to a TLS event creates no event. TLS protects the connection, and `authSecret` still decides who may send. Both can be set on one event.

<!-- astrona:playground:destroy -->
