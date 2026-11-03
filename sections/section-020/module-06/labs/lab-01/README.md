---
estimated_duration: 25m
---

# Lab: Fix A Prometheus Scrape Job

Graded lab. **Status: UNTESTED.** The environment, the reference solution and the validation scripts were written from the upstream manifests and documentation and have never been run. Static checks only (`astrona validate`, `bash -n`, YAML parsing).

The cluster starts with a Prometheus server whose scrape job for the Argo Events controller names the wrong namespace and the wrong port. The task is in `question.md`; the walkthrough is in `solution.md`.

## Run it

```sh
astrona run -c sections/section-020/module-06/labs/lab-01
astrona submit -c sections/section-020/module-06/labs/lab-01
astrona destroy ats-063-lab-020-06
```

Authors prove the reference solution with `astrona test -c sections/section-020/module-06/labs/lab-01`.

## Checks

| Script | What it proves |
| --- | --- |
| `validate-job-discovery.sh` | The job discovers pods in the namespace argo-events |
| `validate-job-port.sh` | The job connects to port 7777 |
| `validate-target-up.sh` | Prometheus reports the target as up |
