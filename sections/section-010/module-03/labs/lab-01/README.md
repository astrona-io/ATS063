---
estimated_duration: 30m
---

# Lab: Fix A Sensor That Never Fires

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a webhook EventSource named fleet that has two events and a Sensor named launch that never runs its trigger. The task is to make the Sensor create a Workflow from either event and to carry the ship name from the request into the Workflow. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/module-03/labs/lab-01
astrona submit -c sections/section-010/module-03/labs/lab-01
astrona destroy ats-063-lab-010-03
```

Authors prove the reference solution with `astrona test -c sections/section-010/module-03/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-launch-conditions.sh` | Sensor launch still depends on both events of EventSource fleet, and its trigger runs when either of them arrives |
| `validate-launch-either-event.sh` | A request to the event scout and a request to the event relay each create exactly one launch- Workflow |
| `validate-launch-carries-ship.sh` | The Workflow parameter ship holds the ship from the request body, for a request to scout and for a request to relay |
| `validate-launch-workflow-succeeds.sh` | The launch- Workflows reach the phase Succeeded |
