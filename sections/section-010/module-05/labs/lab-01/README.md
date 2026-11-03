---
estimated_duration: 30m
---

# Lab: Fix A Kafka EventSource

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a Kafka broker, a Kafka EventSource named dock with a wrong port, a wrong topic and no `jsonBody`, and a Sensor that creates a Workflow from each message. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/module-05/labs/lab-01
astrona submit -c sections/section-010/module-05/labs/lab-01
astrona destroy ats-063-lab-010-05
```

Authors prove the reference solution with `astrona test -c sections/section-010/module-05/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-dock-connection.sh` | The Kafka event arrival reads the topic arrivals from the Service kafka on port 9092 |
| `validate-dock-json-body.sh` | The Kafka event arrival embeds JSON messages as JSON |
| `validate-dock-workflow-ship.sh` | A message creates a dock- Workflow whose parameter ship holds the ship from the message, and the Workflow succeeds |
