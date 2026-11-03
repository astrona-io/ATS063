# Observing And Securing The Components

A running pipeline is made of several components, and each one has its own identity, its own logs and its own network path. When an event does not arrive, you need to know which component to look at, what it is allowed to do, and what it says about itself. This module covers the permissions of the components, the metrics and logs they produce, the limits you can put on network access, and a fixed order for finding the failing component.

## Learning objectives

After this module you can:

- Name the service accounts that the components of Argo Events use, and the permissions each one needs.
- Test what a service account may do with `kubectl auth can-i --as`, and read a `Forbidden` error in the log of a Sensor.
- Read the metrics that the controller serves and the logs of the controller, an EventSource and a Sensor, and set the log level.
- Explain which paths into an EventSource are open, and limit them with a Service type, a NetworkPolicy or an Ingress.
- Follow a symptom to the component that causes it, and repair an EventSource and a Sensor that are wired wrongly.

## Before you start

You know what a service account, a Role and a RoleBinding are, and you can read logs and events with `kubectl`. You have created an EventSource and a Sensor before.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas, ready before you start |
| `starfleet` | pods `shuttle` and `drifter` | Client pods with `curl`, in `starfleet` and `outpost` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

The module has four parts. The first part looks at the permissions of the components. The second part reads metrics and logs. The third part limits who can reach an EventSource. The fourth part gives an order of checks for a pipeline that does not work.

## How the module is built

Each part starts with a problem that you can see in the playground, and then explains the mechanism behind it. The commands create objects in the namespace `starfleet`, and each part deletes what it created, so you can run the parts in order or one at a time.

The module ends with a lab. A webhook EventSource and a Sensor are wired wrongly in three places, and no Workflow is created. You find each fault with the checks from this module and repair it, and the checks of the lab send a real event.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
