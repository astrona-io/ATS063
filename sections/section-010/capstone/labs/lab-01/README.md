---
estimated_duration: 60m
---

# Lab: Build The Harbor Pipeline

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster has an EventBus and a Secret with a token. The task is to build a token-protected webhook EventSource with two events and a Sensor that records each movement in a Workflow. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/capstone/labs/lab-01
astrona submit -c sections/section-010/capstone/labs/lab-01
astrona destroy ats-063-capstone-010
```

Authors prove the reference solution with `astrona test -c sections/section-010/capstone/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-harbor-eventsource.sh` | EventSource harbor has the events arrival and departure on port 12000, both protected by the Secret harbor-token, and is deployed |
| `validate-harbor-sensor.sh` | Sensor logbook depends on both events of harbor, runs its trigger on either of them, and is deployed |
| `validate-harbor-token-enforced.sh` | Requests without a token or with a wrong token create no Workflow, and requests with the token are accepted |
| `validate-harbor-movements-recorded.sh` | Each valid request creates one logbook- Workflow whose parameters hold the ship from the body and the name of the event, and the Workflow succeeds |
