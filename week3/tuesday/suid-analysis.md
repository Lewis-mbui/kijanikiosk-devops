# SUID Misconfiguration Analysis

## 1. Why does Linux ignore SUID on interpreted scripts?

Modern Linux kernels ignore the SUID bit on interpreted scripts (for example shell scripts beginning with `#!`) because of historical race-condition vulnerabilities.

Execution of a script is different from execution of a compiled binary.

Typical interpreted execution flow:

1. User executes the script.
2. Kernel opens the script.
3. Kernel starts the interpreter (for example `/bin/bash`).
4. Interpreter reads the script contents.

Historically, an attacker could replace or modify the script between the moment it was opened and the moment the interpreter consumed it.

This created a race condition where privileged execution could occur on attacker-controlled content.

To eliminate this entire attack class, Linux ignores SUID on interpreted scripts.

As a result, setting SUID on shell scripts does not normally elevate privileges.

---

## 2. If SUID has no effect here, why is SUID + world-write still a critical finding?

Although SUID itself is ignored for shell scripts, the file remained dangerous because it was:

- writable by all users
- executed by a privileged process

In this environment, the deployment script was executed by a root-owned cron job.

That means an attacker does not need SUID escalation.

The attack path becomes:

1. Modify deploy.sh.
2. Wait for root cron execution.
3. Malicious commands execute with root privileges.

Example outcome:

- create privileged users
- install persistence
- read secrets
- modify system services

The dangerous property is trusted execution of untrusted content.

---

## 3. What would make this scenario exploitable in practice?

The vulnerability becomes exploitable whenever a trusted privileged component executes a writable file.

Examples include:

- cron jobs
- systemd services
- deployment automation
- CI/CD pipelines
- administrator maintenance scripts

If the privileged process automatically executes attacker-modified content, arbitrary commands run with elevated privileges.

---

## Remediation Applied

The following remediation was implemented:

- removed SUID bit
- removed world-write permissions
- removed world-execute permissions
- enforced ownership root:root
- set final permissions to 750
- verified no SUID files remain in `/opt/kijanikiosk`

Final state:

```text
-rwxr-x---
root:root
```

Result:

Privilege escalation path eliminated.
