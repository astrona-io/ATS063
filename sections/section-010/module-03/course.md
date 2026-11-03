# Reacting With Sensors And Triggers

An event that nobody reacts to changes nothing. The Sensor is the component that decides when an event is a reason to act, and the trigger is the action that follows. A Sensor listens to the EventBus, remembers which events have arrived, and runs its triggers when the rule it was given is met. This module takes the Sensor apart and shows how data from the event reaches the object that the trigger creates.

## Learning objectives

After this module you can:

- Describe the parts of a Sensor: dependencies, triggers and the service account in the pod template.
- Explain that a Sensor with several dependencies waits for all of them by default, and change that rule with trigger conditions.
- Let several Sensors react to the same event.
- Copy data and context from an event into the object that a trigger creates, with a data key, a context key, a template and a default value.
- Choose where a parameter is written with the destination path and the operation `append`, `prepend` or `overwrite`.
- Create any Kubernetes object from a trigger, and give the Sensor the permission it needs.
- Submit a Workflow with the `argoWorkflow` trigger and explain how it differs from a plain create.

## Before you start

You know how an EventBus, an EventSource and a Sensor connect by name, and you can send a request from the `shuttle` pod with `curl`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | The JetStream bus that the EventSources and Sensors in `starfleet` use |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No EventSource or Sensor exists yet. Each part creates what it needs. The module has four parts. The first part shows the anatomy of a Sensor, how several dependencies combine, and how several Sensors share one event. The second part shows how the data of an event is copied into the object that a trigger creates. The third part uses the Kubernetes trigger to create any object, and the Argo Workflow trigger to submit Workflows. The fourth part follows a fixed list of checks to find out why a Sensor that is deployed receives nothing.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
