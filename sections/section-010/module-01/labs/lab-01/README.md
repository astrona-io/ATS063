---
estimated_duration: 25m
---

# Lab: Build A Webhook Pipeline With Argo Events

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a running EventBus named default in starfleet and nothing else. The task is to add an EventSource and a Sensor so that a webhook request creates a Workflow. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-063-lab-010-01
```

Authors prove the reference solution with `astrona test -c sections/section-010/module-01/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-eventsource-ready.sh` | EventSource webhook has the event mission on POST /mission, port 12000, a Service and is deployed |
| `validate-sensor-ready.sh` | Sensor mission depends on webhook/mission and has a k8s create trigger for a Workflow |
| `validate-event-creates-workflow.sh` | A real webhook request from the shuttle pod creates a Workflow whose message argument is the request message |
| `validate-message-per-event.sh` | Two events create two Workflows with their own messages |
| `validate-workflow-succeeds.sh` | The created Workflow runs to the phase Succeeded |
