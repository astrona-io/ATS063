# Receiving Events With EventSources

An Argo Events pipeline is only as useful as the events that enter it. The EventSource is the component that decides what counts as an event: an HTTP request, a clock tick, or a change of a Kubernetes object. Each kind of EventSource has its own fields, its own failure modes and its own rules about how many pods may run it.

This module covers three EventSource types that need no external service: the webhook, the calendar and the resource EventSource. Together they show the three ways an event can start: something calls you, time passes, or the cluster changes.

## Learning objectives

After this module you can:

- Configure a webhook EventSource with several events, the Service that exposes it, and the health endpoint that comes with it.
- Protect a webhook with a bearer token stored in a Kubernetes Secret.
- Explain the difference between an EventSource name and an event name, and why event names must be unique in one EventSource.
- Produce time-based events with a calendar EventSource, using an interval or a cron schedule, a time zone, excluded dates and a static payload.
- Watch Kubernetes objects with a resource EventSource, restrict it with event types, labels, fields and a name prefix, and give it the permissions it needs.
- Use a log trigger to see the exact event that a Sensor receives.

## Before you start

You need the pipeline basics: an EventBus, an EventSource and a Sensor connect by name, and `kubectl apply` creates them. You know how to send a request from the `shuttle` pod with `curl`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | The JetStream bus that the EventSources and Sensors in `starfleet` use |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `outpost` | pod `drifter` | A client pod in another namespace |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No EventSource or Sensor exists yet. The module has three parts. The first part works with the webhook EventSource: several events, its Service, its health endpoint and token authentication. The second part uses the calendar EventSource for events that come from time. The third part uses the resource EventSource to turn changes of Kubernetes objects into events.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
