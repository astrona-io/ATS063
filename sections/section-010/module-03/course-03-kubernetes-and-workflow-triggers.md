# Kubernetes And Workflow Triggers

The last link of a pipeline is the trigger. A trigger is the only part of Argo Events that changes anything outside Argo Events, so it is also the part where permissions, names and failures matter most. This part uses the two triggers that work inside the cluster. The Kubernetes trigger creates, changes or deletes any object. The Argo Workflow trigger runs Argo Workflows operations, such as submitting a Workflow.

The EventBus `default` already exists in the playground. Everything else in this part is created by you.

## What a trigger is allowed to do

The Sensor pod runs every trigger, and it uses the service account that `spec.template.serviceAccountName` names. The trigger can do exactly what that account may do, and nothing more. This is the reason for the account `event-trigger` in the playground: it may create Workflows in `starfleet` and has no other permission.

The Kubernetes trigger has four operations. The operation `create` creates the object. The operation `update` replaces an object, `patch` changes fields of it, and `delete` removes it. Each operation maps to the Kubernetes API verb of the same name, so the account needs that verb on that resource.

## Create an object the account may not create

Save this as `eventsource-notes.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: notes
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    note:
      port: "12000"
      endpoint: /note
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and wait until it is deployed:

```sh
kubectl apply -f eventsource-notes.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/notes --timeout=180s
```

The Sensor below creates a ConfigMap from every event. The text of the ConfigMap comes from the body of the event. Save this as `sensor-notebook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: notebook
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: note-dep
      eventSourceName: notes
      eventName: note
  triggers:
    - template:
        name: write-note
        k8s:
          operation: create
          source:
            resource:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                generateName: note-
                namespace: starfleet
              data:
                text: unset
          parameters:
            - src:
                dependencyName: note-dep
                dataKey: body.text
              dest: data.text
```

Apply it, send an event and look at the result:

```sh
kubectl apply -f sensor-notebook.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/notebook --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"text":"fuel low"}' http://notes-eventsource-svc:12000/note
kubectl -n starfleet get configmaps
kubectl -n starfleet logs -l sensor-name=notebook --tail=30
```

No ConfigMap whose name starts with `note-` exists. The Sensor log contains an error from the API server that says the service account `event-trigger` cannot create ConfigMaps. The EventSource, the bus and the Sensor all worked. Only the last step was refused, and the evidence is in the log of the Sensor pod, because that pod ran the trigger.

## Give the account the permission

The fix is a Role with the verb `create` on ConfigMaps and a binding to the account. Save this as `rbac-notes.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: trigger-configmaps
  namespace: starfleet
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: trigger-configmaps
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: trigger-configmaps
subjects:
  - kind: ServiceAccount
    name: event-trigger
    namespace: starfleet
```

Apply it and send a new event. The Sensor does not retry the event that failed, because no retry is configured, so the new event is the test:

```sh
kubectl apply -f rbac-notes.yaml
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"text":"fuel low"}' http://notes-eventsource-svc:12000/note
kubectl -n starfleet get configmaps
```

A ConfigMap with a name that starts with `note-` exists now. Read its text:

```sh
kubectl -n starfleet get configmaps -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.data.text}{"\n"}{end}'
```

The line for the new ConfigMap ends with `fuel low`. The Role grants only `create`. A trigger with the operation `delete` on the same resource needs the verb `delete` in a Role as well, and the same rule holds for `update` and `patch`.

## The Argo Workflow trigger

A Workflow can be created with the Kubernetes trigger. The `argoWorkflow` trigger exists for the cases where a plain create is not enough. Its operation field takes `submit`, `submit-from`, `resubmit`, `resume`, `retry`, `suspend`, `terminate` or `stop`. The operation `submit` is the default. The others act on a Workflow that already exists, for example to retry a failed one or to resume a suspended one, and they need the name of that Workflow.

The Sensor pod implements these operations by running the Argo command line program inside the pod. After a `submit`, the trigger looks up the new Workflow by labels that it has put on it. The Workflow therefore carries the labels `events.argoproj.io/sensor` with the name of the Sensor and `events.argoproj.io/trigger` with the name of the trigger. The lookup needs the verb `list`, so the service account needs more than `create`. Save this as `rbac-operator.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-operator
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-operator
  namespace: starfleet
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["workflows"]
    verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-operator
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-operator
subjects:
  - kind: ServiceAccount
    name: workflow-operator
    namespace: starfleet
```

Now the Sensor. It reuses the event `note` of the EventSource `notes`. Save this as `sensor-relay.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: relay
  namespace: starfleet
spec:
  template:
    serviceAccountName: workflow-operator
  dependencies:
    - name: note-dep
      eventSourceName: notes
      eventName: note
  triggers:
    - template:
        name: submit-relay
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: relay-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: report
                arguments:
                  parameters:
                    - name: message
                      value: unset
                templates:
                  - name: report
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo]
                      args: ["{{inputs.parameters.message}}"]
          parameters:
            - src:
                dependencyName: note-dep
                dataKey: body.text
              dest: spec.arguments.parameters.0.value
```

The parameters sit under `argoWorkflow`, in the same place as under `k8s`. Apply the objects, send one event and list the Workflows by the label that the trigger added:

```sh
kubectl apply -f rbac-operator.yaml
kubectl apply -f sensor-relay.yaml
kubectl -n starfleet wait --for=condition=Deployed sensor/relay --timeout=180s
kubectl -n starfleet exec shuttle -- curl -s -X POST -H 'Content-Type: application/json' -d '{"text":"signal sent"}' http://notes-eventsource-svc:12000/note
kubectl -n starfleet get workflows -l events.argoproj.io/sensor=relay
```

One Workflow with a name that starts with `relay-` exists after a few seconds. Repeat the last command until it appears. The same event also reached the Sensor `notebook`, which created another ConfigMap. This is the fan-out from one event to two triggers in action: each Sensor acts on its own.

## Choose between the two

Use the Kubernetes trigger when the goal is to create or change an object, whatever its kind. Its permission is the plain API verb on the resource. Use the Argo Workflow trigger when the goal is an Argo Workflows operation, especially one on an existing Workflow, or when you want the labels that tie the Workflow to its Sensor and trigger. Both accept the same `source` and `parameters` shapes, and both run with the identity of the Sensor pod.

## Common pitfalls

> [!WARNING]
> Triggers fail quietly from the point of view of the sender.
>
> - The sender of an event gets a normal response even when the trigger is refused. Refusal shows up only in the log of the Sensor pod, so read that log first when an object does not appear.
> - A trigger needs the API verb of its operation, and the `argoWorkflow` trigger with `submit` also needs `list` and `get` on Workflows. A Role that has only `create` is not enough for it.
> - `delete`, `update` and `patch` need the name of the object. A resource with only `generateName` can be created, but not deleted or patched.
> - An event that failed is not run again after you fix the permission. Send a new event to test the fix.
