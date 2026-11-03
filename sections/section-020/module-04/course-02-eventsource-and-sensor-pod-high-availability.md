# EventSource And Sensor Pod High Availability

A single EventSource pod is a single point of failure. When the node restarts, or the pod is evicted, events stop until a new pod is ready, and a webhook caller sees errors in that time. The obvious answer is to run two pods, but two pods are not always safe: two calendar timers would publish every event twice, and two readers of one message queue could split or repeat the messages. This part shows which EventSource types may run on all pods, which ones must have exactly one active pod, and how the pods agree on who that is.

The EventBus `default` is ready in the playground. Every object below is created in the namespace `starfleet`.

## Two kinds of high availability

The documentation sorts the EventSource types into two groups. The group decides what `replicas: 2` means for the type.

| Group | What happens with two pods | Types |
| --- | --- | --- |
| Active-active | Both pods serve traffic at the same time | AWS SNS, AWS SQS, Bitbucket, Bitbucket Server, GitHub, GitLab, NetApp StorageGRID, Slack, Stripe, Webhook |
| Active-passive | One pod serves, the other waits and takes over when the first one is gone | AMQP, Azure Events Hub, Calendar, Emitter, GCP PubSub, Generic, File, HDFS, Kafka, Minio, MQTT, NATS, NSQ, Pulsar, Redis, Resource |

The rule behind the table is simple. A type that receives requests from outside, such as a webhook, can have several receivers, because the Service sends each request to one pod. A type that creates events itself or pulls them from a source, such as a calendar or a queue, must have one active pod, because two active pods would produce each event twice.

One EventSource object must not mix types from the two groups. If a spec has a webhook and a calendar, the controller marks it invalid, and the status shows the reason `InvalidEventSource` with the message `Some types of event sources can not be put in one spec`. Put the two kinds in two objects.

## Active-active: the webhook with two replicas

The field `spec.replicas` on an EventSource sets the number of pods. Save this as `gate.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gate
  namespace: starfleet
spec:
  replicas: 2
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    entry:
      port: "12000"
      endpoint: /entry
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and wait until both pods are ready:

```sh
kubectl apply -f gate.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/gate --timeout=120s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=gate --timeout=120s
kubectl -n starfleet get pods -l eventsource-name=gate
```

Two pods run, and both are ready. The Service `gate-eventsource-svc` sends requests to both. Webhook is an active-active type, so the controller does not start a leader election for it, and no Lease with the name `eventsource-gate` exists:

```sh
kubectl -n starfleet get lease eventsource-gate
```

The command answers `NotFound`. Delete the object when you are done, so that the next steps start clean:

```sh
kubectl -n starfleet delete eventsource gate
```

## Active-passive: the calendar and its leader

A calendar EventSource creates an event on a schedule. With two pods, both would start the timer, so the pods must elect a leader first. The controller sets the environment variable `LEADER_ELECTION` in the pods, and the pod starts an elector before it starts the event source. The default elector uses the EventBus: the pods form a small group through NATS, and one of them becomes leader. The log of a pod says either that it is the leader or that it is not and stands by.

The second elector uses a Kubernetes Lease. You choose it with an annotation on the EventSource:

```yaml
metadata:
  annotations:
    events.argoproj.io/leader-election: k8s
```

A Lease is a small object in the API server that names a holder and a renew time. The name is `eventsource-<name>` for an EventSource and `sensor-<name>` for a Sensor, in the namespace of the object. The holder is the name of the pod. The pod that holds the Lease renews it every second, and the Lease lasts five seconds without a renewal. A standby pod keeps trying to take the Lease. When the leader stops renewing, a standby pod takes over after a few seconds. If the leader pod loses the Lease while it runs, the process exits with the message `leader lost`, and the container restarts.

Creating and updating a Lease is a call to the API server, and the pod makes it with its own ServiceAccount. The default ServiceAccount of a namespace has no permission for it, so the Lease elector needs a ServiceAccount, a Role and a RoleBinding. Save this as `pulse-rbac.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pulse-es
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pulse-lease
  namespace: starfleet
rules:
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pulse-lease
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pulse-lease
subjects:
  - kind: ServiceAccount
    name: pulse-es
    namespace: starfleet
```

The EventSource uses that ServiceAccount through `spec.template.serviceAccountName`. Save this as `pulse.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: pulse
  namespace: starfleet
  annotations:
    events.argoproj.io/leader-election: k8s
spec:
  replicas: 2
  template:
    serviceAccountName: pulse-es
  calendar:
    tick:
      interval: 20s
```

Apply both files, and read the Lease:

```sh
kubectl apply -f pulse-rbac.yaml
kubectl apply -f pulse.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=pulse --timeout=120s
kubectl -n starfleet get lease eventsource-pulse -o jsonpath='{.spec.holderIdentity}{"\n"}'
kubectl -n starfleet get pods -l eventsource-name=pulse
```

The holder is the name of one of the two pods. Both pods are ready, but only the holder creates events. Now remove the leader and watch the Lease move. Replace the pod name with the holder that the first command printed:

```sh
holder=$(kubectl -n starfleet get lease eventsource-pulse -o jsonpath='{.spec.holderIdentity}')
kubectl -n starfleet delete pod "$holder"
sleep 15
kubectl -n starfleet get lease eventsource-pulse -o jsonpath='{.spec.holderIdentity}{"\n"}'
```

The Lease now names the other pod, and the Deployment has started a replacement that waits as a standby. The ticks continue after a short gap, because the new leader starts the timer.

## Sensors are active-passive too

A Sensor has the field `spec.replicas` as well. A Sensor with more than one replica is active-passive: one pod consumes events and fires the triggers, and the other pods wait. With a JetStream bus the election runs through the bus by default, and the annotation `events.argoproj.io/leader-election: k8s` switches it to a Lease named `sensor-<name>`, with the same permissions as above. Without an election, two Sensor pods would run each trigger twice.

Add a Sensor with two replicas for the calendar. It uses the `log` trigger again. Save this as `pulse-sensor.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: pulse
  namespace: starfleet
spec:
  replicas: 2
  dependencies:
    - name: tick-dep
      eventSourceName: pulse
      eventName: tick
  triggers:
    - template:
        name: note
        log: {}
```

```sh
kubectl apply -f pulse-sensor.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=pulse --timeout=120s
kubectl -n starfleet logs -l sensor-name=pulse --tail=5
```

Both pods are ready. The log lines about events come from the pod that is active.

## Never scale the Deployment by hand

The generated Deployment is an implementation detail of the controller. The documentation says not to scale it manually, for two reasons. First, the number of pods in the election group comes from `spec.replicas`, so a Deployment with three pods and a spec with two leaves the elector with the wrong size. Second, the controller updates the Deployment only when the hash of the spec changes, so a manual change is not reverted either. The Deployment then differs from the spec until the next real change. Change `spec.replicas` on the EventSource or the Sensor, and let the controller update the Deployment.

Clean up before the next part:

```sh
kubectl -n starfleet delete sensor pulse
kubectl -n starfleet delete eventsource pulse
kubectl delete -f pulse-rbac.yaml
```

## Common pitfalls

> [!WARNING]
> With the annotation `events.argoproj.io/leader-election: k8s`, a missing Role for Leases does not produce an error on apply. The pods start and report as ready, no pod gets the Lease, so no pod becomes leader, and an active-passive EventSource publishes nothing. When events are missing from a replicated calendar or queue EventSource, check for the Lease first.
