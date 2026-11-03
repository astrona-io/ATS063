# Summary

The Argo Events controller is one Deployment named `controller-manager` in the namespace `argo-events`. One process runs the EventBus, EventSource and Sensor controllers, and it reads its defaults from the ConfigMap `argo-events-controller-config`. The three custom resource definitions accept any field under `spec`, so a misspelled or unknown field is ignored without an error. The cluster installation gives the controller a ClusterRole, and the namespace installation uses a Role and the flag `--namespaced`. The validating webhook is optional, and it refuses many wrong specs at apply time.

For an EventSource the controller creates a Deployment with the name prefix `<name>-eventsource-`, and a Service named `<name>-eventsource-svc` when the spec has service ports. For a Sensor it creates a Deployment with the name prefix `<name>-sensor-` and no Service. The Deployments carry the labels `eventsource-name` or `sensor-name`, they are owned by the object, and they are removed when the object is deleted. The controller updates a Deployment only when the hash of the spec changes.

Webhook, GitHub, Slack and the other request-driven types are active-active, so every pod serves traffic. Calendar, Kafka, NATS, Redis and the other pulling types are active-passive, and one elected pod serves while the others wait. One EventSource must not mix the two groups. The election runs through the EventBus by default. The annotation `events.argoproj.io/leader-election: k8s` switches it to a Lease named `eventsource-<name>` or `sensor-<name>`, which needs a Role with `get`, `create` and `update` on `leases` for the ServiceAccount of the pods. A Sensor with more than one replica is active-passive.

Set `spec.replicas` on the EventSource or the Sensor, and never scale the generated Deployment by hand. The template has flat fields: `serviceAccountName`, `container`, `volumes`, `securityContext`, `nodeSelector`, `tolerations`, `affinity`, `priorityClassName` and `imagePullSecrets`. The `container` fields are merged into the container `main`. The labels in the template go to the pods, and the labels in the metadata of the object go to the Deployment.

When a pod does not run, read the status conditions, then the events of the pod, then the logs of the pod, and then the log of the controller. The condition `Deployed` shows only that the Deployment exists.

Key facts:

- The controller image in this course is `quay.io/argoproj/argo-events:v1.9.6`.
- Short names are `eb`, `es` and `sn`.
- The Lease timings are a duration of 5 seconds, a renew deadline of 2 seconds and a retry period of 1 second.
- A missing bus gives the reason `EventBusNotFound`, and an invalid spec gives the reason `InvalidEventSource`.
- The log level is set with the environment variable `LOG_LEVEL`.

One controller serves every namespace of the cluster, but each namespace owns its own EventBus, EventSources, Sensors and service accounts. A dependency and `eventBusName` have no namespace field, so a Sensor never reaches an EventSource in another namespace. A request from another namespace reaches an EventSource through the name `<service>.<namespace>.svc`. The namespace installation runs the controller with `--namespaced` and limits what it manages.

<!-- astrona:playground:destroy -->
