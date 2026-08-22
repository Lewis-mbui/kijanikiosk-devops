# KijaniKiosk Continuous Delivery Quality Process

## Purpose

Every time a developer finishes a change and saves it to the team's shared code repository, an automated quality process begins immediately. Instead of relying on someone to manually check the code, the system performs the same series of checks every time, ensuring that only software meeting the team's quality standards is recorded as an approved release candidate.

This gives the team confidence that every published version has been built, tested, and reviewed in a consistent way before it is made available for future deployment.

---

## How the Process Works

| Step    | What it Confirms                                                                                             |
| ------- | ------------------------------------------------------------------------------------------------------------ |
| Lint    | The source code follows agreed coding standards and contains no obvious programming mistakes.                |
| Build   | The application can be successfully assembled into a deployable package.                                     |
| Verify  | Automated tests confirm expected behaviour, while dependency checks look for known security vulnerabilities. |
| Archive | A copy of the successful build is safely stored together with identifying information.                       |
| Publish | The approved package is stored in the central software registry with its own unique version number.          |

The process always runs in the same isolated environment. This means every developer's work is checked under identical conditions regardless of which computer originally created the change. By removing differences between development machines, the results become predictable and repeatable.

Once the code passes the initial quality checks, it is assembled into a deployable package. This package represents the exact version that will later be deployed into higher environments. Before it is accepted, automated tests confirm that the application's core behaviour is still correct. At the same time, a security check examines the application's external software libraries for publicly known vulnerabilities.

Running these checks at the same time reduces waiting without reducing quality. The overall process finishes in well under a minute while still performing multiple independent validations.

If every check succeeds, the finished package is stored in the organisation's software registry. Every published version receives a unique identifier that combines the application's version number with the source code revision that produced it. This makes every published package fully traceable back to the exact change that created it.

For a financial services platform, this traceability is particularly valuable. If a problem is ever discovered in production, the team can identify exactly which version is running, determine the precise source code used to build it, and reproduce that same version for investigation or recovery.

---

## What Happens When Something Goes Wrong

The process stops as soon as it discovers a problem that would make later work unnecessary. For example, if the source code contains a basic programming mistake, there is little value in building, testing, and publishing it. Ending the process early saves time and allows developers to correct the problem quickly.

Some quality checks run independently at the same time. If one of these discovers a problem, the others are allowed to finish so that developers receive the fullest possible picture of what needs attention instead of fixing one issue only to discover another later.

When a problem occurs, no new version is added to the software registry. Only packages that successfully complete every required quality check become available for future deployment.

---

## Current Scope

This process provides strong automated validation of source code quality, successful builds, automated testing, dependency security checks, version tracking, and secure package storage. It does not yet perform long-running integration testing, performance testing under production-scale workloads, or automatic deployment into running environments. Those capabilities are planned for later stages of the delivery platform as the project continues to mature.
