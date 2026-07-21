# Deployment Strategy Analysis

## Scenario 1: The Overnight Batch Processor

**Selected Strategy:** Rolling Deployment

A rolling deployment is the most appropriate choice because the workload runs on a single dedicated worker VM with no customer-facing traffic, the infrastructure budget only allows one environment, and a rollback within 24 hours is acceptable. Although rollback is slower than blue/green, the strategy avoids duplicate infrastructure and the changed output format does not create a mixed-version problem because only one batch job is running at a time.

---

## Scenario 2: The User-Facing Authentication Service

**Selected Strategy:** Blue/Green Deployment

Blue/green deployment is the best choice because the new JWT token format is not backwards-compatible, making mixed-version traffic unacceptable, while the requirement for rollback in under five minutes is met by an instant traffic switch back to the previous environment. The available budget for duplicate infrastructure during deployment also satisfies the primary cost trade-off of the blue/green strategy.

---

## Scenario 3: The Machine Learning Recommendation Engine

**Selected Strategy:** Canary Deployment

A canary deployment is the most appropriate strategy because the team wants to compare the new recommendation model against the existing production baseline under real traffic, accepts simultaneous use of both versions, and already has the monitoring infrastructure required for progressive rollout. During each rollout stage, the team should collect click-through rate and request latency for both model versions; if the canary demonstrates improved click-through rate without violating latency SLOs, traffic can be increased, but if performance degrades or latency exceeds acceptable thresholds, the rollout should stop immediately and all traffic should be routed back to the stable model.
