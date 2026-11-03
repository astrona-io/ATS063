# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it, sets it up, grades your work and removes it again. This page lists the tools you need, the `astrona` commands you use every day, and what to do when a start goes wrong.

## What you need

- A container engine: Docker or Podman. The cluster runs inside it.
- `kind`, which runs Kubernetes inside the container engine.
- `kubectl`, which talks to the cluster. You use it on every page.
- The `astrona` command-line tool.
- About 4 GiB of free memory. The EventBus of Argo Events runs three server pods, next to the controllers of Argo Workflows and Argo Events.
- Outbound internet while an environment starts. The setup downloads the Argo Workflows and Argo Events manifests and the container images at pinned versions.

You do not install Argo Workflows or Argo Events yourself. The setup of each environment installs them in the cluster, at the version the course is written for: Argo Events 1.9.6 and Argo Workflows 3.7.3 on Kubernetes 1.35.

Let `astrona` check your machine:

```sh
astrona setup
astrona check
```

`astrona setup` shows each step it would take and asks before it does anything. `astrona check` tells you what is missing.

## The commands you use every day

Each module page and lab page shows the exact command to copy. In short:

- `astrona run -c <path>` creates the cluster for a playground or a lab and runs its setup.
- `astrona submit -c .` grades a lab against the running cluster. Run it from the directory of the lab, or give the lab path.
- `astrona list` shows the environments that exist, and `astrona destroy <name>` removes one.

The first start of an environment takes several minutes, because it downloads images. A start that fails with network errors usually means that the machine has no outbound internet or that the container engine is out of memory.

## Environment notes for this course

- The namespaces are `starfleet` and `outpost`. The pods `shuttle` and `drifter` carry `curl`, so you can send requests to a webhook from inside the cluster.
- Argo Events runs as one controller for the whole cluster in the namespace `argo-events`. Your EventSources, Sensors and EventBus live in `starfleet`.
- A Workflow that a Sensor creates needs the service account `workflow-runner`, and a Sensor needs the service account `event-trigger`. Both exist in `starfleet`.

Static checks of this course verify files and scripts. They do not replace a run on a cluster. The labs and playgrounds are marked untested until a run is recorded.
