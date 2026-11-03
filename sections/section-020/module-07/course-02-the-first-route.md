# The First Route

This part writes an Ingress for the EventSource from the first part and posts an event through the controller. It also shows how the controller turns an Ingress into a running route.

## Check the controller

The controller runs in `ingress-nginx` and watches Ingress objects that name its class:

<!-- astrona:playground:renew -->

```sh
kubectl get ingressclass
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc ingress-nginx-controller
```

The IngressClass is named `nginx`. An Ingress that does not name a class, or names another one, is ignored by this controller. The Service `ingress-nginx-controller` is the entry point. On kind it is of the type NodePort, and the controller pod is also reachable on the host ports 80 and 443 of its node. This module uses the Service from inside the cluster.

## Create the pipeline

Save this as `fleet.yaml`:

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

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l sensor-name=fleet --timeout=180s
```

## Write the Ingress

Save this as `fleet-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fleet
  namespace: starfleet
spec:
  ingressClassName: nginx
  rules:
    - host: fleet.example.test
      http:
        paths:
          - path: /report
            pathType: Exact
            backend:
              service:
                name: fleet-eventsource-svc
                port:
                  number: 12000
```

Each field has a job:

- `ingressClassName` selects the controller.
- `host` limits the rule to requests whose Host header matches.
- `path` and `pathType` select the request path. `Exact` matches only that path. `Prefix` matches that path and everything below it.
- `backend.service` names the Service and a port number of that Service.

The path is forwarded unchanged. The request `/report` reaches the EventSource as `/report`, which is the `endpoint` of the event. The Ingress does not rewrite it unless you add an annotation for that.

```sh
kubectl apply -f fleet-ingress.yaml
kubectl -n starfleet get ingress fleet
```

## Post an event through the controller

Define the helper from the overview of the playground, or use `curl` directly:

```sh
kubectl -n starfleet exec shuttle -- curl -s -m 10 -w '\nstatus=%{http_code}\n' -H 'Host: fleet.example.test' -X POST -d '{"ship":"scout"}' http://ingress-nginx-controller.ingress-nginx.svc/report
```

If the controller has not loaded the new route yet, the first request gets a 404 from the controller. Wait a few seconds and send it again. The status 200 means that the EventSource accepted the event. Then read the Workflows:

```sh
kubectl -n starfleet get workflows
```

A Workflow named `report-...` shows that the whole route works: the Ingress, the Service, the EventSource, the bus and the Sensor.

## What the controller did

The controller read the Ingress, looked up the endpoints of the Service and wrote them into its own proxy configuration. It sends the request to a pod IP directly and does not go through the Service address. This is why a Service without endpoints cannot receive traffic, even if the Service object exists.

## Clean up

```sh
kubectl -n starfleet delete ingress fleet
kubectl -n starfleet delete -f fleet.yaml
```

## Common pitfalls

> [!WARNING]
> - **Leaving out `ingressClassName`.** No controller takes the Ingress and requests get no route.
> - **Sending a request without the Host header.** A rule with a host does not match, and the controller answers 404.
> - **Using `Exact` and sending `/report/`.** The trailing slash is another path.
> - **Reading a 200 as a created Workflow.** The 200 comes from the EventSource. Check the Workflows to see the Sensor result.
