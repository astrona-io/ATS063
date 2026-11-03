# The EventBus And JetStream

Between an EventSource and a Sensor there is no direct connection. Every event travels through the EventBus, a message service that the controller installs in the namespace. The bus is the reason that EventSources and Sensors can start in any order, restart independently and scale on their own. It is also the first component to check when events disappear. This module explains what the controller builds for an EventBus, how events are stored and delivered, and how to configure persistence, limits and an external service.

## Learning objectives

After this module you can:

- Create an EventBus and name the objects that the controller builds for it: a StatefulSet, a Service, a ConfigMap and two Secrets.
- Explain how an EventSource or a Sensor finds its bus, and use `eventBusName` for a bus that is not named `default`.
- Describe the stream, the subjects and the durable consumers that JetStream uses, and read the merged stream configuration from the status of the bus.
- Set limits on the stream with `streamConfig`, such as `maxAge` and `maxMsgs`, and explain what the default `duplicates` window does.
- Add persistent storage to the bus, set server options with `settings` and `startArgs`, and explain what is lost without persistence.
- Describe the external JetStream option `jetstreamExotic` and the place of the other bus types.

## Before you start

You know how an EventSource and a Sensor connect by name, and you can send a request from the `shuttle` pod with `curl`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No EventBus exists yet. You create it in the first part. The module has four parts. The first part creates a bus and takes apart what the controller builds. The second part follows an event through the stream and reads the stream settings. The third part adds storage and server options and describes external buses. The fourth part breaks a bus on purpose and follows the checks from the status down to the pods and the clients.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
