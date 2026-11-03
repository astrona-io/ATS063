# Metrics With Prometheus

Logs tell you what one component did with one event. Metrics tell you how a component behaves over time, and they are what a monitoring system collects, stores and alerts on. Argo Events components serve metrics in the Prometheus text format. This module shows where the metrics are, how a Prometheus server finds them, how to add scrape jobs, and how to write rules that report a pipeline that has stopped.

## Learning objectives

After this module you can:

- Name the components of Argo Events that serve metrics, and fetch the metrics page of the controller by hand.
- Explain how a Prometheus server finds its targets with pod discovery and relabeling.
- Read the targets, run a query and read a result through the HTTP API of Prometheus.
- Add a scrape job to the configuration, reload the server and confirm the new target.
- Check which ports the pods of an EventSource and a Sensor declare before you scrape them.
- Write a rule that fires when a target is down or missing, and read its state.

## Before you start

You can read the logs and the status of the components, and you know what a ConfigMap is and how a pod mounts one. You do not need to know PromQL beyond the query `up`.

The playground is a kind cluster with Argo Workflows and Argo Events installed. It contains the following objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `argo-events` | Deployment `controller-manager` | The Argo Events controller |
| `starfleet` | EventBus `default` | A JetStream bus with three replicas, ready before you start |
| `starfleet` | Deployment and Service `prometheus` | A Prometheus server on port 9090 |
| `starfleet` | ConfigMap `prometheus-config` | The configuration of the server, with one scrape job |
| `starfleet` | pod `shuttle` | A client pod with `curl` |
| `starfleet` | service accounts `event-trigger` and `workflow-runner` | The identity of Sensors and of Workflow pods |

The module has four parts. The first part looks at the metrics endpoints. The second part follows how Prometheus scrapes the controller. The third part adds jobs for other pods. The fourth part writes rules for missing targets.

## How the module is built

Each part starts with something you can see in the playground and then explains the mechanism. The commands create objects in the namespace `starfleet`, and each part restores what it changed. The module ends with a lab in which a Prometheus server has a scrape job that finds no target, and you repair the job.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
