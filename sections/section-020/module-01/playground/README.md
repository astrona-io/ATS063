# The EventBus And JetStream - Playground

- **Slug:** ats-063-playground-020-01
- **Type:** Astrona playground - clean environment, no task, no grading
- **Status:** UNTESTED. Written from the upstream manifests and documentation; never run.

A kind cluster with Argo Workflows and Argo Events installed. No EventBus, EventSource or Sensor exists.

## Run it

```sh
astrona run -c sections/section-020/module-01/playground
astrona destroy ats-063-playground-020-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the config path. `astrona submit` and `astrona test` do not apply: there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `bootstrap/setup.sh` | Installs Argo Workflows v3.7.3 and Argo Events v1.9.6, then calls `bootstrap/prepare.sh` when it exists |
| `bootstrap/manifests/` | Starfleet workloads, service accounts and module-specific starting objects |
| `docs/overview.md` | What the environment contains and practice tasks |
