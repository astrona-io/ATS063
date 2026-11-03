# Permissions Of The Components

Four identities act in an Argo Events pipeline, and each one is stopped by a different missing permission. The controller needs rights to build Deployments and Services. The pods of an EventSource and a Sensor need rights to read their own objects and, when they use a Lease, to manage that Lease. A Sensor needs the right to create whatever its trigger creates. Missing rights do not stop the pipeline loudly: the objects exist, the pods run, and the failure is a line in a log.

This part lists the identities, tests them with `kubectl auth can-i`, and breaks a Sensor on purpose so that you see what a missing permission looks like.

## The four identities

- The controller runs as the service account `argo-events-controller-sa` in the namespace `argo-events`. The install manifest binds it to a ClusterRole in the cluster installation and to a Role in the namespace installation. You do not change this binding in normal use.
- An EventSource pod runs as the service account named in `spec.template.serviceAccountName`, or as the service account `default` of its namespace when the field is empty. Most EventSources need no extra rights. A calendar or NATS EventSource with a Lease needs the Lease rights that the high availability module described. A resource EventSource needs `get`, `list` and `watch` on the resource it watches.
- A Sensor pod runs as the service account in `spec.template.serviceAccountName`, or as `default`. The pod itself needs no extra rights for ordinary work. The trigger runs inside this pod, so the trigger uses this identity to create the object.
- Workflow pods run as the service account in the Workflow spec. Argo Workflows needs it to write the results of its tasks.

The playground has two prepared service accounts. `event-trigger` may create Workflows in `starfleet`, and `workflow-runner` may write task results. Read the Role of the first one:

```sh
kubectl -n starfleet get role event-trigger -o yaml
```

The rule allows the verb `create` on the resource `workflows` in the API group `argoproj.io`. It does not allow `get` or `list`.

## Test an identity with can-i

`kubectl auth can-i` asks the API server if an identity may do an action. The flag `--as` makes the question about another identity. A service account is written as `system:serviceaccount:<namespace>:<name>`. Your own account is the cluster administrator in the playground, so it may impersonate the others.

```sh
kubectl auth can-i create workflows.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:event-trigger
kubectl auth can-i create workflows.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:default
kubectl auth can-i delete workflows.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:event-trigger
```

The command prints `yes` or `no`. The first answer is `yes` because of the Role above. The second answer is `no`, because the service account `default` has no Role. The third answer is `no`, because the Role has only `create`.

List everything an identity may do in one namespace with `--list`:

```sh
kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:event-trigger
```

The table has one row for each resource and the verbs allowed on it. A short list is a good sign: a Sensor identity should hold only what its trigger needs.

## A Sensor without the right to create

Create a webhook EventSource and a Sensor that does not name a service account. Save this as `fleet-no-sa.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: fleet
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    report:
      port: "12000"
      endpoint: /report
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: fleet
  namespace: starfleet
spec:
  dependencies:
    - name: report-dep
      eventSourceName: fleet
      eventName: report
  triggers:
    - template:
        name: run-report
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: report-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo, report]
```

<!-- astrona:playground:renew -->

Apply it and wait for both objects:

```sh
kubectl apply -f fleet-no-sa.yaml
kubectl -n starfleet wait --for=condition=Deployed eventsource/fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Deployed sensor/fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=fleet --timeout=180s
```

Send one event from the pod `shuttle`:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{"ship":"scout"}' http://fleet-eventsource-svc:12000/report
```

The EventSource answers with a success code, because it accepted the request. Nothing else happens. List the Workflows, and read the log of the Sensor:

```sh
kubectl -n starfleet get workflows
kubectl -n starfleet logs -l sensor-name=fleet --tail=30
```

There is no Workflow. The log of the Sensor holds an error from the Kubernetes API that says the service account `default` in `starfleet` cannot create the resource `workflows` in the API group `argoproj.io`. The error names the identity, the verb and the resource. These three words are what you need to write the missing rule.

## Repair it

The Sensor needs an identity that may create Workflows. Add `serviceAccountName` to the template of the Sensor. Save this as `fleet-sa.yaml`, which changes only the Sensor:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: fleet
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
    - name: report-dep
      eventSourceName: fleet
      eventName: report
  triggers:
    - template:
        name: run-report
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: report-
              spec:
                serviceAccountName: workflow-runner
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: docker.io/library/busybox:1.37
                      command: [echo, report]
```

Apply it and wait for the new Sensor pod. The controller replaces the pod because the template changed:

```sh
kubectl apply -f fleet-sa.yaml
kubectl -n starfleet get pods -l sensor-name=fleet
```

Repeat the second command until only one pod is listed and it is `Running`. Then send the event again and list the Workflows:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{"ship":"scout"}' http://fleet-eventsource-svc:12000/report
kubectl -n starfleet get workflows
```

A Workflow named `report-...` appears. The identity of the Sensor decided the result, and no field of the Sensor or the EventSource changed except the identity.

Delete the objects when you are done:

```sh
kubectl -n starfleet delete -f fleet-sa.yaml
kubectl -n starfleet delete eventsource fleet
```

## Give the smallest set of rights

A Sensor identity should hold the verbs its trigger uses and nothing more. A trigger with `operation: create` needs `create`. A trigger with `operation: patch` or `update` needs `patch` or `update` on the named resource, and `get` may be needed too. A Role for one namespace is enough for a Sensor that acts in its own namespace. Use a ClusterRole only when a trigger acts in other namespaces, and then bind it only where needed.

## Common pitfalls

> [!WARNING]
> - **Reading the Sensor status instead of the log.** The Sensor is `Deployed` and the pod is `Running` while every trigger fails with `Forbidden`.
> - **Granting rights to the wrong identity.** The Workflow pods, the Sensor pod and the controller are three identities. The error names the one that is missing a right.
> - **Using `cluster-admin` to make an error disappear.** The Sensor then can create anything in the cluster. Write the rule the error names.
> - **Forgetting that `default` is an identity.** A pod without `serviceAccountName` uses the service account `default` of its namespace.
