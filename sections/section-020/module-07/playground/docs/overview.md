# Overview: Exposing Webhooks Through Ingress (Playground)

This is a playground, not a lab. It starts a fresh cluster with Argo Workflows, Argo Events and the ingress-nginx controller installed, and then waits. There is no task, no `astrona submit` and no pass or fail. Build objects, break them, run `astrona destroy` and start again.

## What is in the environment

- A kind cluster running Kubernetes 1.35. `kubectl` points at it as the cluster administrator.
- Argo Events v1.9.6 in `argo-events`, installed for the whole cluster, and Argo Workflows v3.7.3 in `argo`.
- The ingress-nginx controller (kind provider manifest, controller v1.12.0) in `ingress-nginx`, with the IngressClass `nginx`.
- In `starfleet`: an EventBus named `default`, the pod `shuttle` with `curl`, and the service accounts `event-trigger` and `workflow-runner`.
- No EventSource, no Sensor and no Ingress exists.

## Helper

The cluster has no port mapping to your computer, so requests go from the pod `shuttle` to the controller Service, with the Host header that the Ingress rule expects:

```sh
hit() { kubectl -n starfleet exec shuttle -- curl -s -m 10 -w '\nstatus=%{http_code}\n' -H "Host: $1" "http://ingress-nginx-controller.ingress-nginx.svc${@:2}"; }
```

Use `hit fleet.example.test /report -X POST -d '{}'` to post to a host and a path.

## Practice tasks

- Create a webhook EventSource and read the Service that the controller creates for it.
- Write an Ingress that routes a host and a path to that Service and post an event through it.
- Put two EventSources behind one host with two paths.
- Break the Ingress on purpose (wrong Service name, wrong port, wrong path) and read the status code each time.
- Add a TLS Secret and call the host over HTTPS.
