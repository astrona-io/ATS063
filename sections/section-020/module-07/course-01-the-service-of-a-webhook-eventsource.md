# The Service Of A Webhook EventSource

An Ingress forwards traffic to a Service, not to a pod. Before you write one, you need to know which Service exists for a webhook EventSource, which port it exposes and which path the pod answers on.

## The Service is optional

A webhook EventSource starts an HTTP server in its pod. The controller creates a Service for it only when the EventSource has a `service` section. Without that section the pod still listens, but only on its pod IP, which changes whenever the pod is replaced.

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
```

<!-- astrona:playground:renew -->

```sh
kubectl apply -f fleet.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
```

## Read the Service

```sh
kubectl -n starfleet get svc
kubectl -n starfleet get svc fleet-eventsource-svc -o yaml
```

The Service is named after the EventSource with the suffix `-eventsource-svc`. Its selector matches the labels of the EventSource pod, and its port list comes from the `service` section. The Ingress backend must use exactly this name and one of these ports.

List the endpoints behind it:

```sh
kubectl -n starfleet get endpoints fleet-eventsource-svc
```

An address in the list means that a ready pod matches the selector. An empty list means that the Service has no pod, and an Ingress that points at it fails.

## Port, targetPort and the port in the event

Three numbers appear and they must line up:

- `port` of the Service is what clients and the Ingress connect to.
- `targetPort` of the Service is the port in the pod.
- `port` in the webhook event is the port that the HTTP server of the EventSource listens on.

In the example all three are 12000. If the event says 12000 and `targetPort` says 12001, the Service accepts a connection and the pod refuses it.

## Test the Service from inside

```sh
kubectl -n starfleet exec shuttle -- curl -s -m 10 -w '\nstatus=%{http_code}\n' -X POST -d '{}' http://fleet-eventsource-svc.starfleet.svc:12000/report
```

The EventSource answers with the status 200 when it accepted the request. A request to another path gets a 404 from the EventSource itself. Keep this test, because it separates a fault in the EventSource from a fault in the Ingress.

## Clean up

```sh
kubectl -n starfleet delete -f fleet.yaml
```

## Common pitfalls

> [!WARNING]
> - **Leaving out the `service` section.** No Service exists and the Ingress has nothing to point at.
> - **Guessing the Service name.** It is `<EventSource name>-eventsource-svc`.
> - **Different numbers in `targetPort` and in the event.** The Service accepts the connection and the pod refuses it.
> - **Testing only through the Ingress.** Test the Service first, so you know where a fault is.
