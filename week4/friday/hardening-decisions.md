# Hardening Decisions

## Purpose

This document explains the security decisions made while building the KijaniKiosk staging infrastructure. It is written to explain the reasoning behind those decisions rather than the technical implementation details.

The objective was not to create the most restrictive environment possible. Instead, the goal was to produce an environment that is predictable, reproducible and easier to operate safely. Every control was evaluated against two questions:

- Does it reduce meaningful operational risk?
- Can the environment still be deployed and maintained reliably?

The resulting design balances security with maintainability so that future engineers can understand both the protections that were introduced and the reasons they were chosen.

---

## Security Decisions

| Control                               | What it does                                                                                                        | Risk mitigated                                                                                                       |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Dedicated service accounts            | Runs each application component under its own identity instead of sharing a privileged account.                     | Reduces the impact of a compromise by limiting access to only the resources that service requires.                   |
| Restricted shared access              | Allows controlled collaboration through explicit shared permissions instead of broad access.                        | Prevents one service from accidentally modifying another service's data while still allowing legitimate cooperation. |
| Security group rules                  | Allows only the required network traffic while denying unnecessary inbound access.                                  | Reduces exposure to unsolicited network connections and limits the available attack surface.                         |
| SSH key authentication                | Uses cryptographic keys for administrative access instead of password-based logins.                                 | Protects against password guessing attacks and improves administrative accountability.                               |
| Infrastructure as Code                | Stores infrastructure definitions as version-controlled code instead of manual configuration.                       | Reduces configuration drift and makes changes auditable and repeatable.                                              |
| Read-only operating system protection | Prevents application services from modifying operating system components while allowing writes only where required. | Reduces accidental system modification and limits the impact of compromised services.                                |
| Service isolation                     | Separates services from unnecessary kernel features, devices, temporary storage and process visibility.             | Limits opportunities for privilege escalation and reduces interaction between unrelated workloads.                   |
| System call restrictions              | Removes groups of unnecessary operating system capabilities while preserving normal application behaviour.          | Reduces the available attack surface if an application vulnerability is exploited.                                   |

---

## Why Infrastructure Was Automated

One of the most important security improvements was moving from manual provisioning to an automated deployment pipeline.

When infrastructure is created manually, differences naturally appear over time as servers are rebuilt, repaired or updated by different engineers. Those differences become difficult to detect and even harder to explain.

Using Infrastructure as Code creates a single reviewed specification that can be reproduced whenever a new environment is required. The same configuration is used each time, making unexpected differences much less likely.

The deployment pipeline also demonstrates reproducibility. Running it a second time produced no infrastructure changes and no configuration changes, providing evidence that the documented state matches the deployed state rather than relying on manual verification.

---

## Why Service Hardening Was Incremental

Reducing the exposure score was treated as an engineering exercise rather than a competition for the lowest possible number.

Additional protections were introduced gradually, with each change followed by verification that the service continued to operate correctly. This approach ensured that security improvements did not unintentionally reduce reliability or create failures that would only appear later in production.

The final `kk-payments` service achieved a security exposure score of **1.9**, exceeding the project requirement of remaining below **2.5** while continuing to start and operate successfully.

Stopping after meeting the required objective reflects an important engineering principle: every additional restriction should have a clear security benefit that outweighs the operational cost.

---

## Why Some Decisions Were Chosen Carefully

Several controls that appear attractive at first were intentionally avoided because they could create unnecessary operational risk.

For example, complete network isolation would produce a stronger security posture on paper, but payment services commonly require communication with external systems. Applying that restriction without understanding future application requirements could prevent legitimate business functionality.

Similarly, extremely aggressive operating system restrictions can improve security metrics while introducing compatibility problems that may not appear until the application experiences real production traffic.

The objective throughout this project was therefore to apply controls that provide measurable risk reduction without creating hidden operational problems.

---

## Current Security Posture

The resulting environment provides multiple complementary layers of protection.

Infrastructure provisioning is automated and reproducible. Administrative access is limited through controlled authentication. Network exposure is restricted to the services that are intentionally published. Application services execute with limited privileges and reduced access to operating system resources. Repeated deployments converge to the same configuration instead of gradually drifting over time.

These controls work together to reduce the likelihood that a single mistake or compromised component will affect the remainder of the environment.

---

## What This Environment Does Not Protect Against

Although the environment represents a significant improvement over a manually configured deployment, it should not be considered production-ready.

These controls do not prevent vulnerabilities within the application itself, protect sensitive business data from software defects, or replace continuous monitoring and incident response. They also do not address software supply-chain risks, backup and disaster recovery, secret rotation, distributed logging, or advanced intrusion detection.

Security is therefore best viewed as a continuous process rather than a finished state. The current design establishes a strong and reproducible foundation that can support additional operational controls as the platform evolves.
