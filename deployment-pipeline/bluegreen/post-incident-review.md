# Post-Incident Review – Week 5 Monday Deployment Incident

## 1. Incident Summary

The KijaniKiosk staging API became unavailable for **48 seconds** during an investor demonstration on Monday morning. A deployment was accidentally directed at the wrong environment, causing the running service to restart with an incorrect configuration. Normal service was restored after the previous configuration was reapplied.

---

## 2. Timeline

| Time  | Event                                                                                  | Owner      |
| ----- | -------------------------------------------------------------------------------------- | ---------- |
| 09:12 | Nia begins the investor walkthrough using the staging environment.                     | Nia        |
| 09:15 | Amina runs `make configure ENV=production` instead of the intended staging deployment. | Amina      |
| 09:15 | The Ansible playbook starts executing against the production environment.              | Automation |
| 09:16 | The production `kk-api` service restarts with the new configuration.                   | Automation |
| 09:16 | Nia observes a `503` error during the demonstration.                                   | Nia        |
| 09:17 | Nia notifies Tendo that the service is unavailable.                                    | Nia        |
| 09:18 | Tendo identifies the incorrect `ENV` value from the terminal history.                  | Tendo      |
| 09:19 | Tendo restores the previous configuration manually.                                    | Tendo      |
| 09:20 | The `kk-api` service restarts successfully with the previous configuration.            | Automation |
| 09:20 | Service availability is confirmed and the incident ends after 48 seconds.              | Tendo      |

---

## 3. Root Cause (Five Whys)

**Why** did the wrong environment receive the deployment?
Because `ENV=production` was supplied to the deployment command.

**Why** was the wrong value supplied?
Because the deployment target was entered manually by the engineer.

**Why** was the deployment target entered manually?
Because the deployment process relied on a runtime parameter instead of deriving the environment automatically.

**Why** did the deployment process rely on a runtime parameter?
Because the deployment tooling had not yet been integrated with the CI/CD pipeline to determine the correct target automatically.

**Root Cause:**
The deployment process accepted a manually supplied environment parameter without validating it against the branch or pipeline context, allowing an environment mismatch to reach production.

---

## 4. Contributing Factors

- The deployment was performed manually during a time-sensitive investor demonstration, increasing the chance of operator error.
- The deployment tooling accepted any valid `ENV` value without validating whether it matched the intended deployment target.
- The same deployment command and credentials could be used for both staging and production environments.

---

## 5. Prevention Mechanisms

| Contributing Factor           | Prevention Mechanism                                                                                                                                        |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Manual environment selection  | Remove the manual `ENV` parameter and derive the deployment environment automatically in the **`set-environment` job** of `deploy.yml`.                     |
| Unvalidated deployment target | Update **`deploy.yml`** so the deployment target is determined from `github.ref_name` instead of user input.                                                |
| Shared deployment access      | Configure **GitHub Environment protection rules** with environment-scoped secrets and a required production approval before production deployments execute. |

---

## 6. Action Items

| Action                                                                                                           | Owner | Target        |
| ---------------------------------------------------------------------------------------------------------------- | ----- | ------------- |
| Remove the manual `ENV` parameter and derive the deployment target automatically in `deploy.yml`.                | Amina | End of Week 5 |
| Configure a required production approval gate before production deployments can execute.                         | Tendo | End of Week 5 |
| Verify future investor demonstrations use the protected deployment pipeline instead of manual terminal commands. | Nia   | Week 6        |
