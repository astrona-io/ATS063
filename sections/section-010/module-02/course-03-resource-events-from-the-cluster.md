# Resource Events From The Cluster

A change inside the cluster is an event too. A ConfigMap is edited, a Workflow finishes, or a pod is deleted. The resource EventSource watches Kubernetes objects through the API server and turns each change into an event. Sensors can then react to the cluster itself, with no external system involved.

The EventBus `default` exists in the playground. The permissions, the EventSource and the Sensor in this part are created by you.

## How a resource EventSource works

The EventSource pod opens a watch on one kind of object, and the API server sends it a notification for every change. The event data describes the change:

- `type` is `ADD`, `UPDATE` or `DELETE`.
- `body` is the whole object as JSON.
- `group`, `version` and `resource` identify the kind of object.

Two consequences follow. The pod needs permission to read the kind it watches, because it calls the API server with its own service account. And it receives the object as it is, so the event body can be large.

The event types `ADD`, `UPDATE` and `DELETE` are the three kinds of change. The field `eventTypes` is required. It lists the changes that become events, so a list with only `ADD` ignores updates and deletions. An EventSource without it is invalid.

## Give the EventSource permission to watch

The EventSource pod runs as the service account that is set in `spec.template.serviceAccountName`. That account needs the verbs `get`, `list` and `watch` on the watched resource. Create the service account, a Role and a binding for ConfigMaps in `starfleet`:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet create serviceaccount resource-watcher
kubectl -n starfleet create role configmap-watcher --verb=get,list,watch --resource=configmaps
kubectl -n starfleet create rolebinding resource-watcher-configmaps --role=configmap-watcher --serviceaccount=starfleet:resource-watcher
```

Each command prints one line that ends in `created`. Check the permission from the point of view of the service account:

```sh
kubectl auth can-i watch configmaps -n starfleet --as=system:serviceaccount:starfleet:resource-watcher
```

The answer is `yes`. Without this permission the EventSource pod starts, but its watch fails, and no event is ever published.

## Create the resource EventSource

Save this as `eventsource-resource.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: resource
  namespace: starfleet
spec:
  template:
    serviceAccountName: resource-watcher
  resource:
    beacon:
      namespace: starfleet
      group: ""
      version: v1
      resource: configmaps
      eventTypes:
        - ADD
        - UPDATE
        - DELETE
      filter:
        afterStart: true
        labels:
          - key: app
            operation: "=="
            value: beacon
```

The event is named `beacon`. The fields `group`, `version` and `resource` select the kind. For the core API group the group is the empty string, and the resource is the plural name `configmaps`. The `namespace` limits the watch to one namespace, and an event without a namespace watches all of them, which then needs permission in all of them.

Under `filter`, `afterStart: true` ignores objects that exist before the EventSource starts. Without it, every existing object that matches would produce an `ADD` event at startup. The entry under `labels` is a label selector that the API server applies, so only ConfigMaps with the label `app=beacon` are sent to the pod.

Apply the file and wait until it is deployed:

```sh
kubectl apply -f eventsource-resource.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/resource --timeout=180s
```

Add a Sensor with a log trigger. Save this as `sensor-beacon-log.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: beacon-log
  namespace: starfleet
spec:
  dependencies:
    - name: change
      eventSourceName: resource
      eventName: beacon
  triggers:
    - template:
        name: print-change
        log: {}
```

```sh
kubectl apply -f sensor-beacon-log.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/beacon-log --timeout=180s
```

## Make changes and read the events

Create a labelled ConfigMap and a ConfigMap without the label. Save this as `beacons.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: beacon-1
  namespace: starfleet
  labels:
    app: beacon
data:
  level: "1"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: plain-1
  namespace: starfleet
data:
  level: "1"
```

Apply it, change the labelled ConfigMap, and delete both:

```sh
kubectl apply -f beacons.yaml
kubectl -n starfleet patch configmap beacon-1 --type merge -p '{"data":{"level":"2"}}'
kubectl -n starfleet delete configmap beacon-1 plain-1
```

Wait a few seconds and list the change types in the order that the Sensor logged them:

```sh
kubectl -n starfleet logs -l sensor-name=beacon-log | grep -o -E 'ADD|UPDATE|DELETE'
```

The labelled ConfigMap produced three events, one for the creation, one for the patch and one for the deletion, in that order. The ConfigMap `plain-1` produced none, because the label selector kept it out of the watch. If a type shows up more than once, the API server sent more than one notification for the same object, which is normal for real objects that controllers update.

## Narrow the watch

The label selector is one of four ways to narrow a resource event. They are all part of `filter`:

- `labels` is a list of label selectors with a key, an operation and a value. The operation defaults to equality.
- `fields` is a list of field selectors. The key can be any field path of the object, for example `metadata.name`, and the value can be a pattern such as `my*`.
- `prefix` keeps only objects whose name starts with the given text.
- `afterStart` ignores the objects that exist before the EventSource starts.

The labels and the fields are applied when the watch is created. For everything else, such as annotations, the EventSource sends the event on, and a Sensor data filter decides. The cost is different. A watch filter keeps the event out of the bus entirely. A Sensor filter lets it through the bus and drops it at the Sensor.

## Where this is used

A resource EventSource is how one platform component reacts to another. A common case is to watch Workflows with a completion label and to start the next step when one finishes. Another is to watch a ConfigMap that holds a deployment request. The EventSource type has an active-passive high availability rule, so with several replicas one pod watches and the others wait to take over.

## Common pitfalls

> [!WARNING]
> - **Forgetting the service account.** The EventSource pod runs as the account in `spec.template.serviceAccountName`. Without `get`, `list` and `watch` on the resource, no event is published.
> - **Using the singular kind.** The field `resource` takes the plural resource name such as `configmaps`, not `ConfigMap`.
> - **Leaving out `eventTypes`.** The field is required. Without it the EventSource is rejected as invalid.
> - **Leaving out `afterStart`.** Existing matching objects then produce an `ADD` event each time the EventSource pod starts.
> - **Filtering on annotations in the EventSource.** Labels and fields are applied by the API server. Annotations need a Sensor data filter.
> - **Expecting a small event body.** The body is the complete object, so large objects make large events.
