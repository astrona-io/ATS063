# Trigger Types, Policies And Delivery Guarantees

A Sensor does more than create Workflows. It can send an HTTP request, write a log line, change an existing object or control a running Workflow, and it decides for each of these whether the action worked. When it decides wrongly, events disappear without an error. This module covers the trigger types beyond the plain Workflow, the policy and retry settings that define success and failure, and the delivery settings that decide what happens to a message that cannot be delivered.

## Learning objectives

After this module you can:

- Use the `http` trigger with a method, a payload built from event data and headers, and the `log` trigger for debugging.
- Choose between the operations `create`, `update`, `patch` and `delete` of the `k8s` trigger, set a patch strategy, and grant the verbs that the Sensor needs.
- Name the eight operations of the `argoWorkflow` trigger and say what each one needs.
- Set `policy.status` for HTTP triggers and `policy.k8s` with `errorOnBackoffTimeout` for triggers that create objects.
- Configure a `retryStrategy` with steps, duration, factor and jitter, and explain why it has no effect without `atLeastOnce`.
- Combine `atLeastOnce` and `dlqTrigger` so that a message that cannot be delivered is parked, and use `rateLimit` and `revisionHistoryLimit`.

## Before you start

You know how an EventSource and a Sensor connect through the EventBus, and you can send a request from the `shuttle` pod with `curl`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas |
| `starfleet` | pod and Service `beacon` | A small HTTP service that rejects some requests on purpose and records every request |
| `starfleet` | EventSource `gate` | A webhook with the events `relay` on port 12000 and `board` on port 13000 |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No Sensor exists yet. The module has four parts. The first part sends an event to the HTTP, log and Kubernetes triggers and reads the operations of the Workflow trigger. The second part defines failure with policies and repeats failed triggers. The third part adds a dead letter trigger and rate limit, and states what the Sensor guarantees. The fourth part joins two pipelines with an HTTP trigger that sends a bearer token from a Secret.

## How to work through it

Each part has commands that you run in the playground. The beacon service writes every request it receives to a file, so after each experiment you can count what really arrived and compare it with what the Sensor reported. Most surprises in this module come from the difference between the two. Version 1.9.6 of Argo Events is the reference for every field and every behavior in the text, and the statements about behavior come from its source code.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
