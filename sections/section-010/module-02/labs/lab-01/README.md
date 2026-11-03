---
estimated_duration: 30m
---

# Lab: Secure A Webhook And Add A Calendar Event

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with an unprotected webhook EventSource named dispatch, a Sensor that turns each request into a Workflow, and a Secret with a token. The task is to require the token and to add a scheduled event. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-010/module-02/labs/lab-01
astrona submit -c sections/section-010/module-02/labs/lab-01
astrona destroy ats-063-lab-010-02
```

Authors prove the reference solution with `astrona test -c sections/section-010/module-02/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-order-auth-configured.sh` | The event order of EventSource dispatch reads its token from the Secret dispatch-token, key token |
| `validate-order-requires-token.sh` | A real request with the bearer token creates a Workflow, and requests with no token, a wrong token or no Bearer prefix create none |
| `validate-ticker-eventsource.sh` | EventSource ticker has a calendar event beat that fires at least once a minute and is deployed |
| `validate-ticker-creates-workflows.sh` | Sensor ticker creates beat- Workflows on every tick and they succeed |
