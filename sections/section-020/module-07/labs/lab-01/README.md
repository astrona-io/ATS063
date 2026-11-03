---
estimated_duration: 25m
---

# Lab: Fix An Ingress For A Webhook

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with the ingress-nginx controller, a webhook EventSource named gate and a Sensor, and an Ingress with a wrong Service name, a wrong port and a wrong path. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-07/labs/lab-01
astrona submit -c sections/section-020/module-07/labs/lab-01
astrona destroy ats-063-lab-020-07
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-07/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-ingress-backend.sh` | The backend is the Service gate-eventsource-svc on port 12000 |
| `validate-ingress-path.sh` | The rule matches the path /report |
| `validate-event-through-ingress.sh` | A POST through the controller creates a gate- Workflow that succeeds |
