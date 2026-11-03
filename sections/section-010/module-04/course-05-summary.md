# Summary

An EventSource has one field under `spec` for each type, and each type holds a map of named events. The types fall into four groups by how an event reaches the EventSource pod. Pushed types, such as the webhook, GitHub, Slack and SNS types, receive HTTP requests and need a Service and a route from the sender. Subscription types, such as NATS, Kafka, AMQP, MQTT and SQS, connect out to a broker and need no Service. Watching types, such as the resource, file and SFTP types, read changes with the permissions of the pod. Generating types, such as the calendar and generic types, create events from a clock or from a gRPC server.

Pushed types can run as several active pods. The other groups run one active pod with standby pods, because two active pods would publish each message twice. After an event reaches the pod, every type publishes it to the EventBus the same way, with a context that holds the type, the EventSource name and the event name.

The NATS type shows the subscription pattern. The event has a `url`, a `subject`, an optional `jsonBody` and a `connectionBackoff`. The data of the event holds the NATS subject and the body. A plain NATS subject is not durable, so messages that are published while the pod is down are lost. The `jsonBody` setting embeds JSON messages as JSON and does not accept messages that are not JSON.

The GitHub and SNS types register a webhook with the outside service and need a public address. The SQS type polls a queue and needs outbound access only. Every credential is a reference to a key of a Secret in the namespace of the EventSource, and a signature check, such as `webhookSecret` or `validateSignature`, stops forged requests.

Several types can share one EventSource. Event names must be unique across the whole object, and the types share one pod, one service account, one template and one high availability model. Put events together when one team owns them and they change together.

Key facts:

- A misspelled type name is not refused by the custom resource definition. The EventSource has no events for it.
- The `subject` in the event context is the event name, not the NATS subject.
- A Sensor with several dependencies and no conditions waits for all of them.

<!-- astrona:playground:destroy -->
