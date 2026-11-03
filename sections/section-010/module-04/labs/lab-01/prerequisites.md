# Prerequisites

- The `astrona` command-line tool, installed and working (`astrona check` passes).
- A container engine that kind can use (Podman or Docker) with about 4 GiB of free memory, and internet access to pull the Argo Workflows and Argo Events manifests and container images.
- `kubectl`.

The lab starts a kind cluster (Kubernetes 1.35) with Argo Workflows and Argo Events installed, a NATS server and the Starfleet workloads in `starfleet` and `outpost`. The first start takes several minutes because it downloads manifests and images.
