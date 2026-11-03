# The Controller, Installation And High Availability

Every EventSource and Sensor in a cluster is only a description until one component turns it into running pods. That component is the Argo Events controller. It is installed once, it reacts to changes of the custom resources, and it decides how many pods run, with which identity and with which resources. This module explains what the controller is and what it builds, how to run EventSource and Sensor pods more than once without duplicating events, and how to set resources, placement and logging through the template of each object.

## Learning objectives

After this module you can:

- Name the objects of an Argo Events installation and explain what the controller, its configuration and its three custom resource definitions do.
- Describe what the controller creates for an EventSource and for a Sensor, and how it labels and owns those objects.
- Choose between the cluster-wide installation and the namespace installation, and explain what the validating webhook adds.
- Explain the difference between active-active and active-passive EventSource types, and name an example of each.
- Configure leader election with the annotation `events.argoproj.io/leader-election`, grant the Role that a Lease needs, and read the Lease holder.
- Set `replicas` on an EventSource and a Sensor, and explain why the generated Deployment must not be scaled by hand.
- Set resources, a ServiceAccount, scheduling constraints and log levels through `spec.template`, and read the status conditions and logs when a pod does not run.

## Before you start

You know what a Deployment, a ServiceAccount, a Role and a RoleBinding are, and you can read the status of a Kubernetes object with `kubectl get -o yaml`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `argo` | Deployment `workflow-controller` | The Argo Workflows controller |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas, ready before you start |
| `starfleet` | pods `shuttle` and `drifter` | Client pods with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors that create Workflows and of Workflow pods |

The module has four parts. The first part looks at the controller and at the objects it builds. The second part runs EventSource and Sensor pods more than once and follows a leader election. The third part sets resources and placement, and reads status and logs to find out why a pod does not run. The fourth part creates a pipeline in a second namespace and shows what the controller shares and what each namespace owns.

## How the module is built

Each part starts with a problem that you can see in the playground, and then explains the mechanism behind it. The commands in the parts create objects in the namespace `starfleet`, and each part deletes what it created, so you can run the parts in order or one at a time. The EventBus `default` is prepared before the playground opens, because every EventSource and Sensor in the module needs a bus to run.

The module ends with a lab. In the lab an EventSource and a Sensor are replicated and should produce a Workflow every twenty seconds, but nothing runs. You find the cause, repair it with the fields of the template and a Role, and the checks of the lab confirm the behavior of the pods, not only the text of the objects.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
