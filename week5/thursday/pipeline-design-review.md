# Pipeline Design Review

## Purpose

This review evaluates the final Jenkins pipeline against the five pipeline design principles introduced during Week 5.

| Principle                        | Status | Evidence                                                                                                                                                                         |
| -------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fail Fast                        | PASS   | A dedicated Lint stage executes before Build. Build failures prevent Verify, Archive, and Publish from running.                                                                  |
| Declare, Don't Inherit           | PASS   | The pipeline declares its execution environment using the `kijanikiosk-node-agent:22` Docker image rather than relying on software installed on the Jenkins controller.          |
| Clean Up Every Build             | PASS   | `cleanWs()` executes in the pipeline `post { always }` block after every build regardless of success or failure.                                                                 |
| Make Diagnostic Output Available | PASS   | JUnit reports are published inside `post { always }` for the Test stage, ensuring results remain available even when tests fail.                                                 |
| Keep the Build Fast              | PASS   | Independent verification tasks (Test and Security Audit) execute in parallel. The successful pipeline completed in approximately 22 seconds, well below the 10-minute guideline. |

## Improvement Implemented

A dedicated Lint stage was introduced before the Build stage.

This improves the pipeline by detecting syntax and static analysis errors before spending time building or verifying the application. It reduces unnecessary work when the source code contains simple issues and follows the fail-fast principle.

## Overall Assessment

The completed pipeline satisfies all five design principles. It executes inside a reproducible Docker environment, performs parallel verification, securely publishes versioned artifacts to Nexus, cleans its workspace after every run, and behaves predictably when failures occur.
