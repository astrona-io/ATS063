---
estimated_duration: 75m
---

# Lab: Build The Escalation Pipeline

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The namespace has no EventBus. The task is to build a dedicated bus with storage, a two-pod EventSource and a Sensor with a data filter and two triggers that react differently to alerts and acknowledgements. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/capstone/labs/lab-01
astrona submit -c sections/section-020/capstone/labs/lab-01
astrona destroy ats-063-capstone-020
```

Authors prove the reference solution with `astrona test -c sections/section-020/capstone/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-signals-bus.sh` | EventBus signals is deployed with 3 replicas, a 1Gi volume claim on each pod, and a merged stream configuration with maxAge 12h |
| `validate-beacon-eventsource.sh` | EventSource beacon uses the bus signals, runs 2 ready pods, and has the events alert and acknowledgement on port 12000 |
| `validate-escalate-filter.sh` | A request to alert with level critical creates one page- Workflow with the site, and a request with another level creates none |
| `validate-escalate-ack.sh` | A request to ack creates one close- Workflow with the site and no page- Workflow |
