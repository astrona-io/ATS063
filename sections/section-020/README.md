# Section 020: Understand Argo Event Components And Architecture

Makes the reader able to configure and operate the components behind the event flow. The section covers the JetStream EventBus, the rules that decide when a Sensor runs a trigger, the trigger types with their retry and delivery settings, and the controller that builds and scales every EventSource and Sensor pod.

**Curriculum item covered:** Understand Argo Event Components and Architecture

---

## What You Will Master

- Describe what the controller builds for an EventBus, and set replicas, persistence, stream limits and a named bus
- Filter events with data, expression, script, context and time filters, and know that a transform runs before the filters
- Combine dependencies with `&&`, `||` and parentheses in trigger conditions, and reset a partial condition with `conditionsReset`
- Use the HTTP, log, Kubernetes and Argo Workflow triggers, and set the policy, retry strategy, dead letter trigger and rate limit
- Explain what the controller does, run EventSource and Sensor pods with high availability, and set resources, labels and placement through the template

---

## The Learning Path

### 1. The EventBus And JetStream
*   **Module Reader:** **[Module 1: The EventBus And JetStream](./module-01/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-01/playground`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-01/playground
    ```

### 2. Sensor Evaluation: Filters, Conditions And Transforms
*   **Module Reader:** **[Module 2: Sensor Evaluation: Filters, Conditions And Transforms](./module-02/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-02/playground`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-02/playground
    ```

### 3. Trigger Types, Policies And Delivery Guarantees
*   **Module Reader:** **[Module 3: Trigger Types, Policies And Delivery Guarantees](./module-03/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-03/playground`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-03/playground
    ```

### 4. The Controller, Installation And High Availability
*   **Module Reader:** **[Module 4: The Controller, Installation And High Availability](./module-04/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-04/playground`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-04/playground
    ```

### 5. Observing And Securing The Components
*   **Module Reader:** **[Module 5: Observing And Securing The Components](./module-05/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-05/playground`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-05/playground
    ```

### 6. Metrics With Prometheus
*   **Module Reader:** **[Module 6: Metrics With Prometheus](./module-06/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-06/playground` — the same cluster with a Prometheus server in `starfleet` that scrapes the controller.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-06/playground
    ```

### 7. Exposing Webhooks Through Ingress
*   **Module Reader:** **[Module 7: Exposing Webhooks Through Ingress](./module-07/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-07/playground` — the same cluster with the ingress-nginx controller installed.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/module-07/playground
    ```

### Section Capstone Challenge
*   **Comprehensive Challenge:** Build The Escalation Pipeline Capstone — `sections/section-020/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS063.git -c sections/section-020/capstone/labs/lab-01
    astrona submit -c .
    ```
*   **Hands-on Objective:** Create a JetStream EventBus with persistence and a stream limit, run a webhook EventSource with two pods on that bus, and write a Sensor with a data filter and two triggers that each wait for one dependency. The grader sends events and checks the Workflows.

---

## Ready for Assessment?

*   **Take the Section 020 Knowledge Check:** `quiz.yaml`
*   **Then take the final domain quiz:** `../final-domain-quiz.yaml`
