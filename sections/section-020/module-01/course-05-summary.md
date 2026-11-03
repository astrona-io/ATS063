# Summary

The EventBus is the message service between EventSources and Sensors. It is a namespaced resource, and a namespace needs one before its EventSources and Sensors work. The common name is `default`, and the field `eventBusName` on an EventSource or a Sensor selects another bus in the same namespace. An object that names a bus that does not exist gets no pod.

For a JetStream bus the controller builds a StatefulSet of server pods, a headless Service, a ConfigMap with the server configuration, a Secret with server keys and a Secret with client credentials. Each server pod has the containers `main`, `reloader` and `metrics`. The controller writes the final address and the stream configuration into the status of the bus, and EventSource and Sensor pods read their connection settings from there. The traffic is encrypted, and clients authenticate with a password.

Events are stored in one stream named `default`. An event travels on the subject `default.<eventsource name>.<event name>`. Each Sensor reads with durable consumers, which remember the position of the Sensor, so a restart of the pod does not lose events that were published in the meantime. Two Sensors on one event have separate consumers and each receives a copy.

The stream is a buffer with limits. The properties `maxMsgs`, `maxAge` and `maxBytes` remove messages whether or not they were read, `replicas` sets the number of copies, `retention` and `discard` decide how the limits act, and `duplicates` is the window in which a repeated message ID is refused. A bus sets only the properties it wants to change in `streamConfig`, and the controller merges them over its global defaults.

Without `persistence`, the data of a server pod lives in an `emptyDir` and is lost with the pod. With `persistence`, each pod has a PersistentVolumeClaim. The fields `settings` and `startArgs` configure the NATS server, and `streamConfig` configures the stream. The list of NATS versions comes from the ConfigMap of the controller. The field `jetstreamExotic` connects the bus to a JetStream service that someone else operates.

Key facts:

- Object names follow the pattern `eventbus-<name>-js` plus a suffix.
- The client address is `nats://eventbus-<name>-js-svc.<namespace>.svc:4222`.
- The default stream limits in the 1.9.6 manifest are 50000 messages, 168 hours and a duplicates window of 300 seconds.
- Deleting the EventBus deletes the stored events.

A broken bus stops every EventSource and Sensor that uses it. Check the status of the EventBus first, then the StatefulSet, the pods and the claims, then the events of a pod that is `Pending`, and last the logs of the server and of the clients. The conditions show what the controller did, not whether the pods are ready. The volume claim template cannot change on a running bus, so a bus with wrong storage settings is replaced, and its stored events are lost.

<!-- astrona:playground:destroy -->
