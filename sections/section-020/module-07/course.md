# Exposing Webhooks Through Ingress

A webhook EventSource listens inside the cluster. Senders outside the cluster cannot reach it until something routes traffic to it. An Ingress is the usual answer: one controller receives the traffic and forwards it by host and path to a Service. This module builds that route with the ingress-nginx controller, puts two EventSources behind one host, and reads the failures that a wrong route produces.

## Learning objectives

After this module you can:

- Name the Service that the controller creates for a webhook EventSource and explain why an Ingress points at that Service.
- Write an Ingress with a host, a path and a backend that delivers a request to an EventSource.
- Explain how the Ingress path and the EventSource `endpoint` interact, and choose `pathType`.
- Put several EventSources behind one host with different paths.
- Read the status code of a failed request and tell which part of the route is wrong.
- Add TLS to an Ingress with a Secret and call the host over HTTPS.

## Before you start

You can create a webhook EventSource and a Sensor, and you know what a Service and an Ingress are. You do not need to know ingress-nginx.

The playground is a kind cluster with Argo Workflows, Argo Events and the ingress-nginx controller installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `ingress-nginx` | Deployment `ingress-nginx-controller` | The ingress controller, with the IngressClass `nginx` |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas, ready before you start |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors and of Workflow pods |

The cluster has no port mapping to your computer. Requests start in the pod `shuttle` and go to the controller Service with a Host header, which gives the same result as a request from outside.

The module has four parts. The first part follows the Service of an EventSource. The second part builds the first route. The third part puts two EventSources behind one host. The fourth part reads the failures and adds TLS.

## How the module is built

Each part creates objects in `starfleet` and removes them at the end. The module ends with a lab in which an Ingress has three faults and no event arrives.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
