---
estimated_duration: 35m
---

# Lab: Build A Dedicated EventBus

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The namespace starfleet has no EventBus. The task is to create an EventBus named audit with three replicas, storage and stream limits, and to run a webhook EventSource and a Sensor through it. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-01/labs/lab-01
astrona submit -c sections/section-020/module-01/labs/lab-01
astrona destroy ats-063-lab-020-01
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-01/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-audit-bus-config.sh` | EventBus audit is deployed with 3 JetStream replicas, and its merged stream configuration has maxAge 24h and maxMsgs 1000 |
| `validate-audit-storage.sh` | Each of the three server pods of the bus audit has a bound 1Gi volume claim |
| `validate-ledger-uses-audit.sh` | EventSource ledger and Sensor ledger both use the bus audit and are deployed |
| `validate-ledger-event-flows.sh` | A request to the webhook creates a ledger- Workflow that carries the message and reaches Succeeded |
