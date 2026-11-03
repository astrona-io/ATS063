---
estimated_duration: 30m
---

# Lab: Fix A Sensor That Admits The Wrong Ships

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a webhook EventSource named beacon with the events dock and clearance, and a Sensor named gatekeeper that never starts a Workflow. The task is to repair the filters, the trigger conditions and the data so that only a scout with enough fuel and a granted clearance is admitted, with the ship name in capitals. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-02/labs/lab-01
astrona submit -c sections/section-020/module-02/labs/lab-01
astrona destroy ats-063-lab-020-02
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-02/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-dock-filter.sh` | Docking requests with class scout and fuel of at least 20 are accepted, and requests with less fuel, another class or a longer class name are dropped |
| `validate-pair-conditions.sh` | The trigger needs both a docking request and a clearance, in either order, and starts exactly one Workflow for each pair |
| `validate-ship-uppercase.sh` | The Workflow parameter ship holds the ship name from the request in capitals |
| `validate-workflow-succeeds.sh` | Sensor gatekeeper still has two dependencies, and the Workflow it creates reaches Succeeded |
