---
estimated_duration: 35m
---

# Lab: Repair A Pipeline That Never Runs

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a webhook EventSource and a Sensor that has three faults: a bus name that does not exist, a wrong event name and a missing service account. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-05/labs/lab-01
astrona submit -c sections/section-020/module-05/labs/lab-01
astrona destroy ats-063-lab-020-05
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-05/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-eventsource-running.sh` | The EventSource fleet is deployed on the existing EventBus and has one ready pod |
| `validate-sensor-dependency.sh` | The Sensor fleet depends on the event report of the EventSource fleet |
| `validate-sensor-identity.sh` | The pod of the Sensor fleet runs as a service account that may create Workflows |
| `validate-pipeline-end-to-end.sh` | A real request creates a report- Workflow that succeeds |
