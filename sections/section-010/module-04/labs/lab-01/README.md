---
estimated_duration: 30m
---

# Lab: Fix A NATS EventSource

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a NATS server, a NATS EventSource named radio with a wrong subject and no `jsonBody`, and a Sensor that creates a Workflow from each message. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/module-04/labs/lab-01
astrona submit -c sections/section-010/module-04/labs/lab-01
astrona destroy ats-063-lab-010-04
```

Authors prove the reference solution with `astrona test -c sections/section-010/module-04/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-radio-subject.sh` | The NATS event arrival of EventSource radio subscribes to the subject fleet.arrival and is deployed |
| `validate-radio-json-body.sh` | The NATS event arrival embeds JSON messages as JSON |
| `validate-radio-workflow-ship.sh` | A real message creates an arrival- Workflow whose parameter ship holds the ship from the message, and the Workflow succeeds |
