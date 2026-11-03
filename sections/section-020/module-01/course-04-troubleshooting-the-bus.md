# Troubleshooting The Bus

When the EventBus does not work, every EventSource and Sensor on it stops: events are not published and Sensors receive nothing. The symptom shows up far from the cause, in a Sensor that stays silent or an EventSource pod that cannot connect. A fixed order of checks, from the EventBus object down to the server pods and then out to the clients, finds the cause in a few commands.

This part breaks a bus on purpose with a storage setting that cannot be met. It follows the checks that show the fault, and then repairs the bus by replacing it.

## The layers to check

The bus has three layers, and a fault in one layer shows in the layer above it.

- The EventBus object holds the wanted settings and the status that the controller writes.
- The objects that the controller builds from it are the StatefulSet, the Service, the ConfigMap, the Secrets and, with persistence, the PersistentVolumeClaims.
- The server pods run the NATS server with JetStream. If they do not run, the Service has no endpoints and no client can connect.

Check them in this order, because each layer tells you if the next one is worth reading. The status of the EventBus tells you what the controller did. The StatefulSet and its pods tell you what Kubernetes did with it. The events of a pod tell you why Kubernetes could not do more.

## Create a bus that cannot start

Save this as `eventbus-broken.yaml`. It asks for persistent storage in a storage class that does not exist:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: broken
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
    persistence:
      storageClassName: no-such-class
      accessMode: ReadWriteOnce
      volumeSize: 1Gi
```

<!-- astrona:playground:renew -->

Apply it. Do not wait for the condition `Deployed`, because the pods cannot start:

```sh
kubectl apply -f eventbus-broken.yaml
```

## Check 1: the status of the EventBus

Print the conditions that the controller wrote:

```sh
kubectl -n starfleet get eventbus broken -o jsonpath='{.status.conditions}{"\n"}'
```

Each condition has a `type`, a `status`, a `reason` and a `message`. The type `Configured` says whether the controller accepted the settings. The type `Deployed` says whether it created the objects. The controller reports what it did, not whether the pods run, so a bus with the status `True` in both types can still have pods that are not ready. Use the conditions to find controller errors, such as a version that is not on its list, and look further when they are fine.

## Check 2: the objects and the pods

List what the controller built, and the pods of the bus:

```sh
kubectl -n starfleet get statefulset eventbus-broken-js
kubectl -n starfleet get pods | grep eventbus-broken
kubectl -n starfleet get pvc | grep eventbus-broken
```

The StatefulSet exists and shows that fewer pods are ready than it wants. The pod `eventbus-broken-js-0` stays in the state `Pending`, and the claim stays `Pending` too. A StatefulSet starts its pods in order, so the second and third pod do not appear until the first one is ready. The claim `eventbus-broken-js-vol-eventbus-broken-js-0` is the first thing that is not `Bound`.

## Check 3: the events of the pod and the claim

Ask Kubernetes why:

```sh
kubectl -n starfleet describe pvc eventbus-broken-js-vol-eventbus-broken-js-0
kubectl -n starfleet describe pod eventbus-broken-js-0
```

The `Events` section at the end of each description holds the reason. The claim reports that it cannot find the storage class `no-such-class`. The pod reports that it cannot be scheduled because its claim is not bound. This is the cause: the EventBus asked for a storage class that the cluster does not have. List the classes that exist to see the valid names:

```sh
kubectl get storageclass
```

A pod that is `Pending` has not started, so it has no log. A pod that is `CrashLoopBackOff` or `Running` but not ready does have a log. For those, read the log of the `main` container:

```sh
kubectl -n starfleet logs eventbus-default-js-0 -c main --tail=20
```

The command reads the log of a healthy server of the bus `default`, to show the form. The log of a broken server has the errors, for example about a stream that cannot be created or a peer that cannot be reached.

## Check 4: the clients

When the bus pods run but a Sensor stays silent, the fault can sit between the client and the bus. The EventSource and Sensor pods log the connection. Read the log of the pod and look for lines about the bus connection. For an EventSource named `gateway`, the command is:

```sh
kubectl -n starfleet logs -l eventsource-name=gateway --tail=20
```

For a client of the bus `broken`, the log would show repeated attempts to connect to `eventbus-broken-js-svc`, because the Service has no endpoints while the pods are not ready. The name of the Service and the address in the status of the EventBus tell you which bus a client uses:

```sh
kubectl -n starfleet get eventbus broken -o jsonpath='{.status.config.jetstream.url}{"\n"}'
```

If an EventSource names a bus in `eventBusName` and no such bus exists, the pod is not created at all, and the status of the EventSource says so. A missing bus and a broken bus are different faults with different symptoms: the first gives no pod, and the second gives a pod that cannot connect.

## Repair the bus

The storage settings are part of the StatefulSet template, and Kubernetes does not allow a change of the volume claim template of an existing StatefulSet. Replace the bus. Change `storageClassName` in `eventbus-broken.yaml` to a name from the list that `kubectl get storageclass` printed, or remove the whole `persistence` block for a memory-backed bus. Then delete the old bus and apply the file again:

```sh
kubectl -n starfleet delete eventbus broken
kubectl apply -f eventbus-broken.yaml
kubectl -n starfleet wait --for=condition=Deployed eventbus/broken --timeout=300s
kubectl -n starfleet get pods | grep eventbus-broken
```

Wait until the three pods are `Running`. The old claims are removed when the bus is deleted, so the new bus starts with empty storage, and any events that the old bus held are gone.

Delete the bus when you are done:

```sh
kubectl -n starfleet delete eventbus broken
```

You now have a path from a silent pipeline to the cause: the status of the bus, the pods and the claims, the events of the pod, and the log of a server or a client. The question that this does not answer is how much load a healthy bus can take, which depends on the stream limits and the size of the storage.

## Common pitfalls

> [!WARNING]
> - **Trusting the conditions alone.** `Deployed` means that the controller created the objects, not that the pods are ready.
> - **Reading the log of a pod that is `Pending`.** It has none. Read its events with `kubectl describe`.
> - **Editing the persistence settings of a running bus.** The volume claim template cannot change, so replace the bus, and note that its stored events are lost.
> - **Confusing a missing bus with a broken bus.** A missing bus gives an EventSource or a Sensor without a pod. A broken bus gives pods that cannot connect.
