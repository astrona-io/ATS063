# Event-Driven Automation And The Argo Events Flow

Most automation on Kubernetes starts because a person or a schedule starts it. A person runs `kubectl apply`, or a cron job fires at midnight. Event-driven automation starts because something happened: a file arrived, a repository changed, a monitoring system raised an alert, or another service sent an HTTP request. Argo Events is the Argo project that turns these occurrences into Kubernetes actions.

This module explains what an event is, which components handle it and in which order, and how you read the path of one event from the sender to the object it creates. You build a complete working pipeline in the playground and follow a single event through every stage.

## Learning objectives

After this module you can:

- Explain why an external event can start work in a Kubernetes cluster, and how that differs from a manual or scheduled start.
- Name the four stages of an Argo Events pipeline (EventSource, EventBus, Sensor and trigger) and say which component does the work in each stage.
- Describe the structure of an event: the context fields and the data with its header and body.
- Create an EventBus, a webhook EventSource and a Sensor that creates an Argo Workflow from an event.
- Send a test event and follow it through the EventSource pod, the Sensor pod and the resulting Workflow.
- Tell apart the failures of each stage by what you can observe.

## Before you start

You need Kubernetes basics: namespaces, pods, Deployments, Services, and the commands `kubectl get`, `kubectl apply` and `kubectl logs`. You do not need to know Argo Workflows. A Workflow is a Kubernetes custom resource that the Argo Workflows controller runs as one or more pods, and this module only uses very small ones.

The playground is a kind cluster with Argo Workflows and Argo Events already installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller that manages EventBus, EventSource and Sensor objects |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller that runs Workflow objects |
| `starfleet` | pod `shuttle` | A client pod with `curl`, used to send test events from inside the cluster |
| `outpost` | pod `drifter` | A client pod in another namespace |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity a Sensor uses to create Workflows, and the identity the Workflow pods run as |

No EventBus, EventSource or Sensor exists yet. You create them in the second part.

The module has three parts. The first part explains events and the four stages of the flow. The second part builds the first pipeline. The third part follows one event through the pipeline and shows how to find the stage where an event stops.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
