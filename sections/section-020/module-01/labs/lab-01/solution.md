---
draft: true
exam_objectives:
- Understand Argo Event Components and Architecture
---
# Connect EventSource EventBus And Sensor Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-063-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-063-lab-020-01-01" || exit 1
node_name="astro-ats-063-lab-020-01-01-control-plane"
worker_name="astro-ats-063-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The Events and Workflows controllers are installed. The exercise uses an internal webhook and event bus; no external sender is configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create a three-member JetStream bus, webhook EventSource and Sensor. Distinguish ingestion, transport and trigger responsibilities by inspecting each resource and the actual parameterised execution.

Save this as `eventbus-default.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: starfleet
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
---
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook
  namespace: starfleet
spec:
  service:
    ports:
    - port: 12000
      targetPort: 12000
  webhook:
    mission:
      port: '12000'
      endpoint: /mission
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: mission
  namespace: starfleet
spec:
  template:
    serviceAccountName: event-trigger
  dependencies:
  - name: request
    eventSourceName: webhook
    eventName: mission
  triggers:
  - template:
      name: launch
      k8s:
        operation: create
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              name: event-mission
              namespace: starfleet
            spec:
              serviceAccountName: workflow-runner
              entrypoint: produce
              activeDeadlineSeconds: 180
              templates:
              - name: produce
                container:
                  image: docker.io/library/python:3.13-alpine
                  command:
                  - python
                  - -c
                  args:
                  - open("/tmp/result","w").write("{{workflow.parameters.event-id}}")
                outputs:
                  parameters:
                  - name: result
                    valueFrom:
                      path: /tmp/result
              arguments:
                parameters:
                - name: event-id
                  value: unset
        parameters:
        - src:
            dependencyName: request
            dataKey: body.id
          dest: spec.arguments.parameters.0.value
```

Apply the scoped correction:

```sh
kubectl apply -f eventbus-default.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True eventbus/default --timeout=300s
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True eventsource/webhook --timeout=180s
kubectl -n starfleet wait --for=jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'=True sensor/mission --timeout=180s
kubectl -n starfleet exec shuttle -- python -c 'import urllib.request,json; r=urllib.request.Request('"'"'http://webhook-eventsource-svc:12000/mission'"'"',data=json.dumps({'"'"'id'"'"':'"'"'mission-complete'"'"'}).encode(),headers={'"'"'Content-Type'"'"':'"'"'application/json'"'"'}); print(urllib.request.urlopen(r,timeout=5).status)'
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded workflow/event-mission --timeout=240s
```

Deliver a webhook event and execute a Workflow using its data. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-063-lab-020-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
