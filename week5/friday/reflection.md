# Week 5 Friday Reflection

## Question 1

The biggest tension I encountered this week was between following the course material exactly and preserving a working, stable pipeline. One example was the use of shell commands inside the Jenkinsfile's `environment` block to compute the package version and Git SHA. Although a more conventional Declarative Pipeline would calculate these values inside a `script` block, the existing implementation had already been proven through multiple successful builds. Changing it would have introduced unnecessary risk immediately before completing the capstone. I chose to prioritise stability over refactoring because the objective was to deliver a production-ready pipeline whose behaviour had already been verified through successful runs and fault injection. This reinforced an important engineering lesson: improvements should be made deliberately, but unnecessary changes to working production code immediately before release can create avoidable failures.

---

## Question 2

**Board document sentence:**

_"Every time a developer finishes a change and saves it to the team's shared code repository, an automated quality process begins immediately."_

**Technical version:**

_A Git push triggers a Jenkins Declarative Pipeline that checks out the repository, provisions the pinned Docker agent, and executes the Lint, Build, Verify, Archive, and Publish stages defined in the Jenkinsfile._

Both versions describe the same event: a developer submitting code automatically starts the validation process. The difference is the audience. The board version avoids implementation details and focuses on what happens from a business perspective, while the technical version names the specific technologies and execution flow that implement the process.

---

## Question 3

If KijaniKiosk grew from four developers to forty, the first part of the pipeline that would become a bottleneck is build concurrency. The current pipeline uses `disableConcurrentBuilds()`, which serialises builds rather than allowing multiple pipeline executions to proceed simultaneously. With forty developers making frequent commits, builds would spend increasing amounts of time waiting in the queue, delaying feedback and reducing developer productivity. The pipeline would need to evolve by introducing controlled concurrency through a plugin such as Throttle Concurrent Builds, additional Jenkins agents, or distributed build infrastructure capable of running multiple builds in parallel. This would preserve fast feedback while preventing resource exhaustion, allowing the CI system to scale alongside the development team.
