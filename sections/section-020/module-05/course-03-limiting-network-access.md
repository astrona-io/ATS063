# Limiting Network Access

An EventSource of a request-driven type opens a port, and anything that can reach that port can send it an event. Inside a cluster that means every pod, unless you say otherwise. This part shows who can reach a webhook EventSource, how the three levels of exposure differ, and how to restrict access with a NetworkPolicy.

## The three levels of exposure

- The pod has an address inside the cluster. Any pod that knows it can send traffic to the port.
- The Service in `spec.service` gives the EventSource a stable name, `<name>-eventsource-svc`, with the type `ClusterIP` unless you set another type. This is reachable from every namespace through `<name>-eventsource-svc.<namespace>.svc`.
- An Ingress, a Gateway route or a Service of the type `LoadBalancer` or `NodePort` makes it reachable from outside the cluster. Argo Events does not create these, so you create them yourself.

An event also carries no identity of its own. If you must trust the sender, use authentication inside the request (a secret in a header, checked by the Sensor with `secureHeaders` as the TLS part described, or the `authSecret` of the webhook) and use the network to narrow who can try.

## Start with an open EventSource

Save this as `gate.yaml`. It is a webhook EventSource with a Service:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gate
  namespace: starfleet
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    open:
      port: "12000"
      endpoint: /open
      method: POST
```

<!-- astrona:playground:renew -->

Apply it and wait for the pod:

```sh
kubectl apply -f gate.yaml
kubectl -n starfleet wait --for=condition=Ready pod -l eventsource-name=gate --timeout=180s
```

Send a request from the pod `shuttle` in `starfleet` and from the pod `drifter` in `outpost`:

```sh
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://gate-eventsource-svc:12000/open
kubectl -n outpost exec drifter -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://gate-eventsource-svc.starfleet.svc:12000/open
```

Both requests reach the EventSource and get a success code. The second one crossed a namespace boundary without any special setting.

## Allow only the namespace of the EventSource

A NetworkPolicy selects pods and lists which traffic may enter them. A pod that no policy selects accepts all traffic. A pod that a policy selects accepts only what the policies allow. Save this as `gate-policy.yaml`. It selects the pods of the EventSource and allows traffic on the port from pods in `starfleet` only:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gate-from-starfleet
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      eventsource-name: gate
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 12000
```

The empty `podSelector` under `from` means every pod in the namespace of the policy. The policy has no entry for other namespaces, so they are refused.

Apply it and repeat both requests:

```sh
kubectl apply -f gate-policy.yaml
kubectl -n starfleet exec shuttle -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://gate-eventsource-svc:12000/open
kubectl -n outpost exec drifter -- curl -s -m 5 -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' http://gate-eventsource-svc.starfleet.svc:12000/open
```

The first request still gets a success code. If the policy is enforced, the second request does not connect, and `curl` ends after five seconds with the code `000` or an error. A NetworkPolicy has an effect only if the network plugin of the cluster enforces it. Whether the network plugin of your kind cluster does depends on its version and settings. If the second request still succeeds, the cluster accepted the object and ignores it, which is a reason to confirm enforcement in a real cluster before you rely on a policy.

## Which traffic an EventSource and a Sensor need

When you restrict a pod with a policy, list what it needs, or you cut off the pipeline.

- An EventSource pod needs traffic in on its port from the senders, and traffic out to the EventBus, which is the pods of the bus on the port 4222. For an outgoing type, such as NATS or Kafka, it needs traffic out to that broker. It also needs to resolve names, so it needs traffic out to DNS.
- A Sensor pod needs traffic out to the EventBus and to the Kubernetes API server, because the trigger calls the API. It receives no incoming traffic in the ordinary case.
- The EventBus pods need traffic in on 4222 from the EventSource and Sensor pods, and between themselves on the cluster ports for a bus with more than one replica.

A policy with `policyTypes: [Egress]` on an EventSource without these rules makes it unable to publish. The symptom is a log line about a failed connection to the bus.

## Exposing an EventSource outside the cluster

A cluster-internal Service does not expose the EventSource. To receive events from outside, put an Ingress or a Gateway route in front of the Service, and let the controller of that resource terminate the traffic. Then these rules apply:

- Expose only the endpoint paths you need, because the Ingress rule can match on a path.
- Terminate TLS at the Ingress or in the EventSource, as the TLS part explained.
- Authenticate the sender, because the network no longer limits who can send.
- Use the source-specific event types, such as GitHub or Slack, that verify a signature, instead of a plain webhook, when the sender supports it.

## Delete what you created

```sh
kubectl -n starfleet delete networkpolicy gate-from-starfleet
kubectl -n starfleet delete eventsource gate
```

## Common pitfalls

> [!WARNING]
> - **Assuming a NetworkPolicy is enforced.** The object is accepted by the API server even when no plugin acts on it. Test with a request that must fail.
> - **Restricting egress without allowing the bus and DNS.** The pod starts and then cannot publish or resolve names.
> - **Selecting the wrong pods.** The labels of the pods are `eventsource-name` and `sensor-name`. A label that does not exist selects nothing.
> - **Treating the Service as a security boundary.** Any pod in the cluster can use the name of a Service.
