# More EventSource Types - Playground

- **Slug:** ats-063-playground-010-04
- **Type:** Astrona playground - clean environment, no task, no grading
- **Status:** UNTESTED. Written from the upstream manifests and documentation; never run.

A kind cluster with Argo Workflows and Argo Events installed, a running EventBus named default in starfleet, a NATS server (`nats`) and a client pod with the `nats` tool (`natsbox`). No EventSource or Sensor exists.

## Run it

```sh
astrona run -c sections/section-010/module-04/playground
astrona destroy ats-063-playground-010-04
```

`astrona destroy` takes the environment name (`metadata.name`), not the config path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `bootstrap/setup.sh` | Installs Argo Workflows v3.7.3 and Argo Events v1.9.6, then calls `bootstrap/prepare.sh` |
| `bootstrap/manifests/` | Starfleet workloads, service accounts, the EventBus and the NATS server |
| `docs/overview.md` | What the environment contains and practice tasks |
