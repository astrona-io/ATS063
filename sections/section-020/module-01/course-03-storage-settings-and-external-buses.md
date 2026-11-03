# Storage, Settings And External Buses

A bus that works in a test cluster is not yet a bus that you can rely on. The questions that remain are what survives a restart of the server pods, how much memory and disk the stream may use, how to pass options to the NATS server, and what to do when a team already runs a JetStream service of its own. The EventBus spec has a field for each of these. This part sets them one by one and names the effect of each.

The playground has no EventBus. You create one with storage here.

## Storage: memory-backed or on a volume

By default a JetStream bus stores its data in an `emptyDir` volume that the controller adds to each server pod. An `emptyDir` lives as long as the pod. When a pod is deleted and recreated, its data is gone, and the stream has to be rebuilt from the other replicas. When all pods are lost at once, for example when the EventBus object is deleted and created again, every stored event is lost.

The field `persistence` changes this. It makes the StatefulSet request a PersistentVolumeClaim for each pod, so that the data stays on a volume when the pod is replaced. The fields are `storageClassName`, `accessMode` and `volumeSize`. Save this as `eventbus.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
    persistence:
      accessMode: ReadWriteOnce
      volumeSize: 1Gi
    settings: |
      max_file_store: 512MB
    startArgs:
      - "-D"
```

The file also sets two server options that the next sections explain. The field `storageClassName` is left out, so the claims use the default storage class of the cluster. The kind cluster of the playground has one.

<!-- astrona:playground:renew -->

Apply it and wait for the bus:

```sh
kubectl apply -f eventbus.yaml
kubectl -n starfleet wait --for=condition=Deployed eventbus/default --timeout=300s
kubectl -n starfleet get pvc
```

One claim exists for each server pod. The claim name is the volume name `eventbus-default-js-vol` followed by the pod name, so the first one is `eventbus-default-js-vol-eventbus-default-js-0`. A claim can stay `Pending` for a short time while the pod it belongs to is scheduled. Wait until all three are `Bound`.

The claims belong to the StatefulSet, and they stay when a pod is deleted. Delete one pod and watch the replacement come back with the same claim:

```sh
kubectl -n starfleet delete pod eventbus-default-js-1
kubectl -n starfleet wait --for=condition=Ready pod/eventbus-default-js-1 --timeout=180s
kubectl -n starfleet get pvc
```

The list still has three claims, and none of them is new. The upstream controller removes the claims when the EventBus object is deleted, so deleting the bus deletes the stored events even with persistence.

## Server options: settings and startArgs

The `settings` field is text that the controller adds to the NATS server configuration. The documentation gives the example `max_file_store: 1GB`. The global defaults of the controller set `max_memory_store: -1` and `max_file_store: 1TB`, where `-1` means that no limit applies up to the available memory. The comment in the default says that only one of the two limits should be configured and that `store_dir` must not be set, because the controller fixes the directory to `/data/jetstream`.

The `startArgs` field is a list of command-line arguments that are added to the NATS server command. The value `-D` turns on debug logs. Check the effect with the logs of the main container:

```sh
kubectl -n starfleet logs eventbus-default-js-0 -c main --tail=20
```

The output is more verbose than with the default arguments. The fields `settings` and `startArgs` are for the NATS server. The limits of the stream, such as the age of the messages, belong to `streamConfig`. Mixing them up is a common mistake: a stream limit in `settings` is not applied to the stream.

The field `maxPayload` sets the largest message size that the server accepts. It is relevant when an event carries a large body, for example a whole object from a resource EventSource.

## The version list lives in the controller

The `version` field names a NATS server version. The controller does not accept an arbitrary value. It looks the version up in its own configuration, the ConfigMap `argo-events-controller-config` in the namespace of the controller. Read the versions:

```sh
kubectl -n argo-events get configmap argo-events-controller-config -o jsonpath='{.data.controller-config\.yaml}'
```

The text lists the supported JetStream versions, each with the images for the NATS server, the metrics exporter and the configuration reloader, and the command that starts the server. It also holds the global stream defaults that the previous sections described. The upstream documentation says that the list can be extended by editing this ConfigMap. The value `latest` is in the list, and the documentation warns not to use it in a real deployment, because the image behind it changes with the controller version.

## An existing JetStream service

An organization that already runs JetStream does not need a second one. The field `jetstreamExotic` points an EventBus at an existing service instead of installing one:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
spec:
  jetstreamExotic:
    url: nats://nats.example.internal:4222
    accessSecret:
      name: my-secret-name
      key: secret-key
    streamConfig: ""
```

This object is shown for reading and is not applied in the playground. The controller installs no StatefulSet for it. EventSources and Sensors get the address and the secret, and the stream is created in the service that you operate. The server, its storage and its upgrades are then your responsibility.

The other keys under `spec` are the older `nats` type, which the upstream documentation describes as the original NATS streaming service, and `kafka`, which uses a Kafka cluster as the bus. This course uses JetStream because it is the type that the documentation presents as the current one.

## Common pitfalls

> [!WARNING]
> These settings are easy to place in the wrong field.
>
> - Without `persistence`, the data of a server pod is gone when the pod is gone. A bus that must keep events through a node failure needs a volume.
> - `settings` and `startArgs` configure the NATS server, and `streamConfig` configures the stream. A limit in the wrong one has no effect on the stream.
> - A `version` that is not in the controller configuration makes the bus fail to deploy. Read the ConfigMap before you pick one.
> - Deleting the EventBus deletes its claims and the events on them. Back up what you need before you remove a bus.
