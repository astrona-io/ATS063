# Section 010: Understand Argo Events Fundamentals

Makes the reader able to explain and build the Argo Events flow. An event enters the cluster through an EventSource, travels over the EventBus to a Sensor, and a trigger of the Sensor creates a Kubernetes object or an Argo Workflow with data from the event. The section comes first because every later topic, from the bus to high availability, configures one stage of this flow.

**Curriculum item covered:** Understand Argo Events Fundamentals

---

## What You Will Master

- Name the four stages of an event and the object that implements each stage
- Build an EventSource, a Sensor and an EventBus, and follow one event through them with the status, the logs and the Workflow it creates
- Define webhook events with a port, a path and a method, and require a bearer token with `authSecret`
- Use a calendar EventSource with an interval or a cron schedule, and a resource EventSource that watches Kubernetes objects
- Write a Sensor with several dependencies and a condition that runs the trigger on either event
- Copy data from an event into a trigger with `dataKey`, `contextKey`, `dest` and the parameter operations
- Create a Workflow with the Kubernetes trigger and with the Argo Workflow trigger, and give the Sensor the RBAC verbs that these need

---

## The Learning Path

### 1. Event-Driven Automation And The Argo Events Flow
*   **Module Reader:** **[Module 1: Event-Driven Automation And The Argo Events Flow](./module-01/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-01/playground` — kind cluster with Argo Workflows and Argo Events installed. No EventBus, EventSource or Sensor exists.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-01/playground
    ```

### 2. Receiving Events With EventSources
*   **Module Reader:** **[Module 2: Receiving Events With EventSources](./module-02/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-02/playground` — the same cluster with a running EventBus named `default` in `starfleet`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-02/playground
    ```

### 3. Reacting With Sensors And Triggers
*   **Module Reader:** **[Module 3: Reacting With Sensors And Triggers](./module-03/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-03/playground` — the same cluster with a running EventBus named `default` in `starfleet`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/module-03/playground
    ```

### Section Capstone Challenge
*   **Comprehensive Challenge:** Build The Harbor Pipeline Capstone — `sections/section-010/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-010/capstone/labs/lab-01
    astrona submit -c .
    ```
*   **Hands-on Objective:** Build a webhook EventSource with two token-protected events and a Sensor that runs one trigger on either event and records the ship and the event name in a Workflow. The grader sends requests with and without the token and checks the Workflows.

---

## Ready for Assessment?

*   **Take the Section 010 Knowledge Check:** `quiz.yaml`
