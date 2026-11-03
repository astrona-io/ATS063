# The Controller And Installation

An EventSource object does nothing by itself. It is a few lines of YAML stored in the Kubernetes API, and nothing listens on a port or reads a queue until another program notices the object and starts a pod for it. This part looks at that program, at the objects that install it, and at what it builds from an EventSource and a Sensor. Knowing these objects makes every later question about a missing pod much shorter, because you know which component to ask.

The playground already has the controller and an EventBus. Nothing in this part changes them.

## One binary with three controllers

The controller is a Deployment named `controller-manager` in the namespace `argo-events`. It runs one container from the image `quay.io/argoproj/argo-events:v1.9.6` with the argument `controller`. That one process starts three controllers inside it: the EventBus controller, the EventSource controller and the Sensor controller. Each one watches its own custom resource and keeps the objects below it in the shape that the spec describes.

The pod runs as a non-root user, with the ServiceAccount `argo-events-sa`, and it exposes health checks on port 8081 and metrics on port 7777. The process has a few flags:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--leader-election` | `true` | Only one controller pod acts when several run |
| `--namespaced` | `false` | Watch only one namespace |
| `--managed-namespace` | the namespace of the pod | The namespace to watch when `--namespaced` is set |
| `--metrics-port` | `7777` | The port of the metrics endpoint |
| `--health-port` | `8081` | The port of the health endpoints |

The controller also reads a ConfigMap named `argo-events-controller-config`, which it mounts at `/etc/argo-events`. The key `controller-config.yaml` holds the defaults for the EventBus: the list of NATS versions that it can install and the default stream settings. The controller stops with a fatal error when this file is missing or invalid, so the ConfigMap is part of the installation, not an option.

## The custom resource definitions

Three CustomResourceDefinitions describe the objects that the controller manages:

| Resource | Short name | Group |
| --- | --- | --- |
| EventBus | `eb` | `argoproj.io` |
| EventSource | `es` | `argoproj.io` |
| Sensor | `sn` | `argoproj.io` |

All three set `x-kubernetes-preserve-unknown-fields` on `spec`. The API server therefore accepts any field under `spec`, including a field with a typo or a field that does not exist. The controller reads only the fields it knows, so a wrong name is ignored without a message. Keep this in mind in every part: a spec that applies without an error is not proof that the setting works.

<!-- astrona:playground:renew -->

Look at the installation yourself. Start with the controller Deployment and its arguments:

```sh
kubectl -n argo-events get deployment controller-manager
kubectl -n argo-events get deployment controller-manager -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
kubectl -n argo-events get deployment controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The arguments are `["controller"]` and the image is `quay.io/argoproj/argo-events:v1.9.6`. Then read the three definitions and the controller configuration:

```sh
kubectl get crd eventbus.argoproj.io eventsources.argoproj.io sensors.argoproj.io
kubectl -n argo-events get configmap argo-events-controller-config -o jsonpath='{.data.controller-config\.yaml}'
```

The configuration shows the `eventBus` section with the `jetstream` versions and the default stream settings.

## Cluster installation and namespace installation

The playground uses the cluster installation. Its manifest creates the three definitions, the ConfigMap, the ServiceAccount, the Deployment, and a ClusterRole and ClusterRoleBinding named `argo-events-role` and `argo-events-binding`. The cluster role lets the controller create Deployments, StatefulSets, Services, Pods, ConfigMaps, Secrets, PersistentVolumeClaims and Leases in any namespace. Check what the identity of the controller may do in the namespace `starfleet`:

```sh
kubectl auth can-i create deployments --as=system:serviceaccount:argo-events:argo-events-sa -n starfleet
```

The answer is `yes`. A second manifest, the namespace installation, replaces the ClusterRole and ClusterRoleBinding with a Role and a RoleBinding, and adds `--namespaced` to the controller arguments. That controller manages EventBuses, EventSources and Sensors only in its own namespace. Use it when several teams share a cluster and each team may not touch the namespaces of the others. The custom resource definitions are cluster-wide objects in both cases, so installing them still needs a cluster administrator.

A third manifest adds the validating webhook. It creates a Deployment and a Service named `events-webhook`, a ServiceAccount, a ClusterRole and a ClusterRoleBinding. At startup the webhook pod generates a certificate Secret named `events-webhook-certs` and registers a ValidatingWebhookConfiguration named `webhook.argo-events.argoproj.io`. The configuration covers create, update and delete of EventBuses, EventSources and Sensors, and its failure policy is `Ignore`. Without the webhook, a bad spec is accepted by the API server and the error appears later in the status. With it, many mistakes are refused at `kubectl apply`, and changes to fields that must not change are refused too. The playground does not install the webhook, so the examples in this module show the errors in the status.

## What the controller builds for an EventSource

Create a webhook EventSource that has a Service. Save this as `probe.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: probe
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    ping:
      port: "12000"
      endpoint: /ping
      method: POST
```

Apply it and wait for the controller to report the pods as deployed:

```sh
kubectl apply -f probe.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/probe --timeout=120s
kubectl -n starfleet get deployments,services,pods --show-labels
```

The controller created a Deployment whose name starts with `probe-eventsource-` followed by a random suffix, one pod from it, and a Service named `probe-eventsource-svc`. The Service exists only because the spec has `service.ports`. The labels on the Deployment are `controller=eventsource-controller`, `eventsource-name=probe` and `owner-name=probe`. Select the pods by that label whenever you need them:

```sh
kubectl -n starfleet get pods -l eventsource-name=probe
kubectl -n starfleet get deployment -l eventsource-name=probe -o jsonpath='{.items[0].metadata.ownerReferences}{"\n"}'
```

The owner reference names the EventSource `probe` and has `controller: true`. This reference is the reason that deleting the EventSource removes everything that the controller built from it. The Deployment also carries the annotation `resource-spec-hash`, which the controller uses later to decide whether the Deployment needs an update. The pod has one container named `main`, which runs the same image as the controller with the argument `eventsource-service`.

## What the controller builds for a Sensor

A Sensor gets a Deployment too, but never a Service, because a Sensor reads from the bus and does not listen on a port. Save this as `probe-sensor.yaml`. The `log` trigger writes the event to the log of the Sensor pod, so it needs no ServiceAccount permissions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: probe
  namespace: starfleet
spec:
  dependencies:
    - name: ping-dep
      eventSourceName: probe
      eventName: ping
  triggers:
    - template:
        name: note
        log: {}
```

```sh
kubectl apply -f probe-sensor.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/probe --timeout=120s
kubectl -n starfleet get deployment -l sensor-name=probe --show-labels
```

The Deployment name starts with `probe-sensor-`, and its labels are `controller=sensor-controller`, `sensor-name=probe` and `owner-name=probe`. The pod runs the argument `sensor-service`. Send one event through the pipeline and read the Sensor log:

```sh
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"a":1}' http://probe-eventsource-svc:12000/ping
kubectl -n starfleet logs -l sensor-name=probe --tail=10
```

## The controller cleans up after itself

Delete the EventSource and look at the objects again:

```sh
kubectl -n starfleet delete eventsource probe
kubectl -n starfleet get deployments,services -l eventsource-name=probe
```

The EventSource carries a finalizer named `eventsource-controller`, so the object stays for a moment while the controller finishes its work. After a few seconds the Deployment and the Service are gone, because their owner is gone. The Sensor stays and keeps waiting for events from an EventSource that no longer exists. Delete it too:

```sh
kubectl -n starfleet delete sensor probe
```

You can now follow any Argo Events object from the spec to the pod: the custom resource is the source of truth, the controller is the only writer of the Deployment, and the owner reference ties the two together.

## Common pitfalls

> [!WARNING]
> A field with a wrong name is accepted without an error, and the controller ignores it. A common case is a `podSpec` key or a misspelled `serviceAccountName` under `spec.template`: the apply succeeds, the pod runs with the default settings, and nothing in the status tells you. After each change, read the generated Deployment or the pod and confirm that the setting is really there.
