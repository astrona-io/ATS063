# Several EventSources Behind One Host

Senders usually get one host name, and the paths decide which EventSource receives a request. This part puts two EventSources behind one host and shows how paths and path types select between them.

## Two EventSources

Save this as `two.yaml`. The EventSource `fleet` listens on `/report`, and the EventSource `harbor` listens on `/arrival`:

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
kind: EventSource
metadata:
  name: harbor
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12100
        targetPort: 12100
  webhook:
    arrival:
      port: "12100"
      endpoint: /arrival
      method: POST
```

<!-- astrona:playground:renew -->

```sh
kubectl apply -f two.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=fleet --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=harbor --timeout=180s
```

## One Ingress with two paths

Save this as `two-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: starfleet-events
  namespace: starfleet
spec:
  ingressClassName: nginx
  rules:
    - host: events.example.test
      http:
        paths:
          - path: /report
            pathType: Exact
            backend:
              service:
                name: fleet-eventsource-svc
                port:
                  number: 12000
          - path: /arrival
            pathType: Exact
            backend:
              service:
                name: harbor-eventsource-svc
                port:
                  number: 12100
```

```sh
kubectl apply -f two-ingress.yaml
```

Post to each path and compare the status codes:

```sh
for p in report arrival; do
  kubectl -n starfleet exec shuttle -- curl -s -m 10 -o /dev/null -w "$p status=%{http_code}\n" -H 'Host: events.example.test' -X POST -d '{}' "http://ingress-nginx-controller.ingress-nginx.svc/$p"
done
```

A request to a path that no rule lists, such as `/other`, gets a 404 from the controller.

## Path types

- `Exact` matches the path and nothing else.
- `Prefix` matches by path elements. The prefix `/report` matches `/report` and `/report/daily`, but not `/reports`.
- `ImplementationSpecific` leaves the meaning to the controller, so avoid it when a portable rule is possible.

When several rules match, the longest matching path wins, and `Exact` wins over `Prefix`. Because the path is forwarded unchanged, a `Prefix` rule only delivers a request to a webhook whose `endpoint` is the same path. The EventSource does not accept sub-paths of its endpoint.

## Use two hosts instead

Paths work well for a few EventSources. When different teams own different EventSources, give each one a host:

```yaml
spec:
  ingressClassName: nginx
  rules:
    - host: fleet.example.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fleet-eventsource-svc
                port:
                  number: 12000
```

The Ingress above delivers every path of `fleet.example.test` to the Service. Requests for `/report` reach the EventSource, and any other path gets the 404 of the EventSource.

## Webhook authentication

An Ingress that is open to the internet lets anyone post events. The webhook EventSource can require a token in the Authorization header through its `authSecret` field, which names a Secret key. Use it, or an authentication annotation of the controller, when the host is public. Check the field names against the version you run.

## Clean up

```sh
kubectl -n starfleet delete ingress starfleet-events
kubectl -n starfleet delete -f two.yaml
```

## Common pitfalls

> [!WARNING]
> - **Using `Prefix` and expecting sub-paths to reach the EventSource.** The EventSource answers only on its `endpoint`.
> - **Using the same path on one host twice.** Only one backend can win, and the other EventSource never receives anything.
> - **Opening a public host without authentication.** Anyone can create Workflows through your Sensors.
> - **Testing with the wrong Host header.** Each rule has its own host.
