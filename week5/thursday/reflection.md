# Week 5 Thursday Reflection

## Question 1: Docker Agent Isolation in Depth

The quickest solution would be to modify the Docker agent at runtime using the `args` option to mount a host directory that already contains the required `libvips` library. This only requires changing the Jenkinsfile by adding an additional Docker volume mount. The disadvantage is that it introduces a dependency on the host machine, reducing portability because another Jenkins server may not have the same library installed.

The second approach would be to switch to a different base image that already includes `libvips`, for example replacing the Alpine-based image with a Debian- or Ubuntu-based Node.js image that provides the required packages. This requires changing the Docker image referenced in the Jenkinsfile. The disadvantage is that the new image may be significantly larger, increasing download time and storage requirements.

The most maintainable production solution is to modify the Dockerfile for the custom `kijanikiosk-node-agent` image by installing `libvips` during the image build. Jenkins continues using the same image name, but every build receives the dependency automatically. The disadvantage is that maintaining the custom image becomes an additional responsibility, although it provides the most reproducible and reliable build environment.

---

## Question 2: Parallel Stage Design Decisions

Adding an eight-minute integration test suite to the Verify stage would undermine the purpose of providing fast feedback to developers. Although the existing Test and Security Audit branches complete quickly, the Verify stage cannot finish until the longest parallel branch completes. An eight-minute integration test would therefore dominate the build duration and make every commit wait for database-dependent tests. As the pipeline grows, this could easily exceed the recommended ten-minute feedback window.

The correct architecture is to keep the current pipeline focused on fast validation while moving long-running integration tests into a separate Jenkins pipeline that is triggered after successful merges to the main branch or on a scheduled basis. This allows developers to receive rapid confirmation that their code builds, passes unit tests, and has no known dependency vulnerabilities, while still performing comprehensive integration testing before deployment. Separating these responsibilities maintains rapid feedback without sacrificing confidence in the final application.

---

## Question 3: The Week as a Complete System

### Plain language

When a developer finishes a change and sends it to the shared code repository, an automated process immediately starts. A clean, temporary environment is created so the software is always checked under identical conditions. The code is examined for common mistakes, built into a deployable package, tested to confirm that it behaves correctly, and checked for known security issues in its dependencies. If every check succeeds, the finished package is stored in a central repository where future deployment systems can retrieve the exact version that was approved. If any step fails, the process stops immediately, reports the problem, and prevents an unreliable package from being stored. This gives the team confidence that every published version has passed the same automated quality checks.

### Technical explanation

A Git push triggers a Jenkins Declarative Pipeline that executes inside the pinned `kijanikiosk-node-agent:22` Docker image, ensuring a reproducible build environment. The pipeline follows a fail-fast design by running ESLint before the build stage. The application is built, validated, and stashed for downstream stages. The Verify stage executes Jest tests and `npm audit` in parallel, with JUnit reports published through stage-level `post` actions. Successful builds archive fingerprinted artifacts and publish a uniquely versioned npm package to Nexus using credentials injected through `withCredentials`. Workspace cleanup executes in `post { always }`, while success, failure, and status-change notifications provide predictable feedback. Fault injection verified that each stage behaves correctly under failure.

### What is the same and what is different?

Both explanations describe the same sequence of events and the same objective: automatically validating software before making it available for deployment. The difference is the audience. The board-level explanation avoids technical terminology and focuses on business value and risk reduction, while the technical explanation names the specific Jenkins features, Docker agents, parallel stages, credentials, artifact repository, and pipeline behaviours that implement those goals.

---

## Question 4: What the Pipeline Cannot Prevent

One category of problems that can still reach Nexus is business logic errors. Unit tests may all pass while the implemented behaviour is still incorrect because the requirements were misunderstood or an important scenario was never tested. These issues are better detected through integration testing, user acceptance testing, or manual product review. They belong outside the CI pipeline because they often require realistic environments, external systems, or human judgement, making them slower and less suitable for every code commit.

A second category is performance, scalability, and operational issues. The application may build successfully, pass all automated tests, and have no known dependency vulnerabilities while still performing poorly under production traffic or consuming excessive resources. These problems are identified through load testing, performance benchmarking, stress testing, and production-like staging environments. Such testing is intentionally separated from the main CI pipeline because it requires additional infrastructure, longer execution times, and would significantly delay the rapid feedback cycle expected after every developer commit.
