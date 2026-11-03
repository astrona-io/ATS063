# Scaling And Operations

Replicas protect against the loss of a pod, but a pod also needs enough memory to start, a node where it is allowed to run, and a way to tell you what it is doing. Most problems with a Sensor or an EventSource that does not run come from three places: the template of the object, the status that the controller writes, and the logs of the pods. This part sets the fields of the template one by one, breaks the placement on purpose, and reads the status and the logs to find the cause.

The EventBus `default` is ready in the playground. Every object below is created in the namespace `starfleet`.

## The template of an EventSource and a Sensor

Both objects have a field `spec.template` that describes the pods. The fields are flat. There is no `podSpec` key, and a key with that name is accepted by the API server and ignored by the controller. The fields are:

| Field | What it sets |
| --- | --- |
| `metadata.labels` and `metadata.annotations` | Labels and annotations of the pod |
| `serviceAccountName` | The ServiceAccount of the pod |
| `container` | The main container: `resources`, `env`, `envFrom`, `volumeMounts`, `securityContext` and `imagePullPolicy` |
| `volumes` | Volumes of the pod |
| `securityContext` | The security context of the whole pod |
| `nodeSelector`, `tolerations`, `affinity` | Where the pod may run |
| `priorityClassName` and `priority` | The scheduling priority |
| `imagePullSecrets` | Secrets for pulling the image |

The controller merges the `container` fields into the container named `main`, so you never repeat the image or the arguments. A Sensor has the same template. Save this EventSource as `rover.yaml`. It sets resources, a log level and a pod label:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: rover
  namespace: starfleet
  labels:
    fleet: outer-ring
spec:
  template:
    metadata:
      labels:
        role: collector
    container:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 128Mi
      env:
        - name: LOG_LEVEL
          value: debug
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    scan:
      port: "12000"
      endpoint: /scan
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and compare where the two labels ended up:

```sh
kubectl apply -f rover.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=rover --timeout=120s
kubectl -n starfleet get deployment -l eventsource-name=rover --show-labels
kubectl -n starfleet get pods -l eventsource-name=rover --show-labels
```

The label `fleet=outer-ring` comes from the `metadata` of the EventSource, and it appears on the Deployment. The label `role=collector` comes from `template.metadata` and appears on the pod. Read the resources and the environment of the main container:

```sh
kubectl -n starfleet get pods -l eventsource-name=rover -o jsonpath='{.items[0].spec.containers[?(@.name=="main")].resources}{"\n"}'
kubectl -n starfleet get pods -l eventsource-name=rover -o jsonpath='{.items[0].spec.containers[?(@.name=="main")].env[?(@.name=="LOG_LEVEL")].value}{"\n"}'
```

The resources match the template, and the value of `LOG_LEVEL` is `debug`. The values `info`, `debug` and `error` are accepted. The container has no readiness probe, so the pod is ready as soon as the process runs.

## A change of the template replaces the pods

Change the memory limit in `rover.yaml` from `128Mi` to `192Mi` and apply the file again. The controller compares the hash of the spec, finds a difference, and updates the Deployment. The Deployment then replaces the pod through a rolling update:

```sh
kubectl apply -f rover.yaml
kubectl -n starfleet get pods -l eventsource-name=rover -w
```

Stop the watch with `Ctrl+C` when the new pod is running and the old one is gone. Resources, labels, the ServiceAccount and the scheduling fields all work this way: you edit the custom resource, and the controller edits the Deployment.

## A pod that cannot be scheduled

A `nodeSelector` that no node satisfies keeps the pod in the state `Pending`. Add this to the template of `rover.yaml`, next to `container`, and apply the file again:

```yaml
    nodeSelector:
      fleet.example/zone: outer-ring
```

```sh
kubectl apply -f rover.yaml
kubectl -n starfleet get pods -l eventsource-name=rover
```

The new pod stays `Pending`, and the old pod keeps running while the update waits. The status of the EventSource does not show the problem, because the controller did its job and created the Deployment. The reason is in the events of the pod:

```sh
kubectl -n starfleet describe pod -l eventsource-name=rover | grep -A3 Events
```

The events contain a `FailedScheduling` entry that says that no node matched the node selector. The same procedure finds a missing toleration for a tainted node and a request that is larger than any node can offer. Remove the `nodeSelector` from the file, apply it again, and the pod is scheduled.

## What the status tells you

The controller writes conditions into the status of the object. An EventSource has the conditions `SourcesProvided` and `Deployed`. A Sensor has `DependenciesProvided`, `TriggersProvided` and `Deployed`. Each condition has a `type`, a `status`, a `reason` and a `message`. Read them with:

```sh
kubectl -n starfleet get eventsource rover -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{"\n"}{end}'
```

Create an EventSource that names a bus that does not exist. Save this as `lost.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: lost
  namespace: starfleet
spec:
  eventBusName: missing
  calendar:
    tick:
      interval: 30s
```

```sh
kubectl apply -f lost.yaml
kubectl -n starfleet get eventsource lost -o jsonpath='{range .status.conditions[*]}{.type}{" "}{.status}{" "}{.reason}{" "}{.message}{"\n"}{end}'
```

The condition `Deployed` is `False` with the reason `EventBusNotFound`. No Deployment is created, and the controller does not retry through a pod, because there is nothing to start. A bus that exists but is not ready gives a different reason, `EventBusNotReady`. Other reasons that you may meet are `InvalidEventSource`, `InvalidDependencies` and `InvalidTriggers`, which come from a validation of the spec, and `CreateDeploymentFailed` and `UpdateDeploymentFailed`, which come from the API server.

An invalid spec has its own message. A calendar event needs a `schedule` or an `interval`. Replace the contents of `lost.yaml` with an EventSource that has the right bus but a calendar event without either field:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: lost
  namespace: starfleet
spec:
  calendar:
    tick: {}
```

After the apply, the status carries the reason `InvalidEventSource` and a message of the form `Invalid spec: lost - tick`, which names the object and the event that failed the validation.

## Logs and the controller

The pods write to their standard output, and the container is named `main`. Read the log of the EventSource and of a Sensor with a label selector, and add `-c main` when a pod has more than one container:

```sh
kubectl -n starfleet logs -l eventsource-name=rover -c main --tail=20
```

With `LOG_LEVEL=debug`, as set above, the log is longer than the default. A healthy Sensor writes a line that says it started to subscribe to events for its triggers. When that line is missing, the Sensor has not connected to the bus. When a pod does not exist at all, the cause is in the controller, so read its log:

```sh
kubectl -n argo-events logs deployment/controller-manager --tail=30
```

The log of the controller names the object that it reconciles and the error it got. Together with the status conditions, it answers why a Deployment was not created.

Clean up:

```sh
kubectl -n starfleet delete eventsource rover lost
```

## Common pitfalls

> [!WARNING]
> Do not read a `Deployed` condition of `True` as proof that events flow. It means only that the controller created the Deployment. A pod that is `Pending`, a pod that crashes because of a memory limit that is too small, or a calendar without a leader all leave the condition at `True`. Check the pods, then the logs, and then the Lease, in that order.
