# More EventSource Types

The webhook, calendar and resource EventSources cover requests, time and cluster changes. Real pipelines also need events from message queues, from Git hosting services and from cloud services. Argo Events has an EventSource type for each of them, and all types share the same shape: a name for the event, the settings of the connection, and an event that goes to the EventBus.

This module groups the types by how the event reaches the cluster, because that decides what you must expose, what credentials you must provide and how many pods may run. It then runs one messaging type, NATS, end to end, and combines several types in one EventSource.

## Learning objectives

After this module you can:

- Group the EventSource types by how events arrive: pushed to an endpoint, received by a subscription, watched, or generated.
- Say whether a type needs a Service, outbound access or both, and which credentials it reads from Secrets.
- Create a NATS EventSource, publish a message to its subject and read the message in a Sensor.
- Describe the fields that the GitHub, Slack, SNS and SQS types need and what each one does.
- Put events of several types in one EventSource and explain the rules for event names.
- Use `jsonBody` and `connectionBackoff` on a messaging EventSource.

## Before you start

You can create an EventSource and a Sensor, and you can read the log of a Sensor to see an event. You know that an EventSource name and an event name together address one event.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | The JetStream bus for this namespace |
| `starfleet` | pod `nats` and Service `nats` | A NATS server at `nats://nats.starfleet.svc:4222` |
| `starfleet` | pod `natsbox` | A client with the `nats` command-line tool |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

No EventSource or Sensor exists yet. The module has four parts. The first part groups the EventSource types. The second part creates a NATS EventSource and sends it messages. The third part describes the source control and cloud types, which need accounts that the playground does not have. The fourth part combines several types in one EventSource.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
