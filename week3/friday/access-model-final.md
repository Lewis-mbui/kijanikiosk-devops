# KijaniKiosk Final Access Model

## Purpose

This document describes the final ownership, permissions, and access decisions used after integrating all Week 3 provisioning phases.

The design goal was:

- isolate services
- allow controlled collaboration
- preserve log rotation
- remain idempotent across repeated provisioning runs

---

# Identity Model

| Entity      | Purpose                      | Login    |
| ----------- | ---------------------------- | -------- |
| kk-api      | API service                  | disabled |
| kk-payments | Payments service             | disabled |
| kk-logs     | Logging and monitoring       | disabled |
| kijanikiosk | Shared application group     | n/a      |
| amina       | Operator access              | normal   |
| lewis       | Administrator/testing access | normal   |

Service users use:

```text
/nonexistent
/usr/sbin/nologin
```

to prevent interactive login.

---

# Directory Ownership

| Directory                    | Owner       | Group       | Mode |
| ---------------------------- | ----------- | ----------- | ---- |
| /opt/kijanikiosk/api         | kk-api      | kk-api      | 750  |
| /opt/kijanikiosk/payments    | kk-payments | kk-payments | 750  |
| /opt/kijanikiosk/logs        | kk-logs     | kk-logs     | 750  |
| /opt/kijanikiosk/config      | root        | kijanikiosk | 750  |
| /opt/kijanikiosk/shared/logs | kk-logs     | kijanikiosk | 2770 |
| /opt/kijanikiosk/health      | kk-logs     | kijanikiosk | 750  |

---

# ACL Model

## Shared logs

Purpose:
Allow controlled write/read interaction without making logs globally writable.

Configured ACL:

| Subject     | Permission |
| ----------- | ---------- |
| kk-api      | rwx        |
| kk-payments | r-x        |
| lewis       | r-x        |

Default ACLs are enabled.

Reason:

New files created after rotation inherit intended access.

---

## Config directory

Purpose:

Environment files must remain readable while ProtectSystem=strict is active.

Owner:

```text
root:kijanikiosk
```

Permissions:

```text
640
```

Environment files:

```text
api.env
payments-api.env
logging.env
```

---

# Health Directory

Purpose:

Expose provisioning status without exposing logs.

Location:

```text
/opt/kijanikiosk/health
```

Artifact:

```text
last-provision.json
```

Permissions:

```text
640
```

Readable by:

```text
kijanikiosk group
```

Example:

```json
{
  "timestamp": "...",
  "kk-api": "down",
  "kk-payments": "down"
}
```

Down is acceptable because provisioning does not require application startup.

---

# Logrotate Interaction

Rotation policy:

```text
daily
rotate 14
compress
delaycompress
```

Created files:

```text
0640
kk-logs:kijanikiosk
```

Reason:

Without explicit ownership, rotated logs may become unreadable or unwritable.

Verification:

```bash
sudo -u kk-api touch \
/opt/kijanikiosk/shared/logs/test-write.tmp
```

PASS confirms ACL inheritance survived rotation.

---

# Access Philosophy

The final model intentionally favors:

1. explicit ownership
2. least privilege
3. shared group collaboration
4. recoverable convergence

Access is granted through groups and ACLs rather than world-readable permissions.
