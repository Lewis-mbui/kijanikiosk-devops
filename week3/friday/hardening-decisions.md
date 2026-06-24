# Hardening Decisions for KijaniKiosk

## Purpose

This document explains the security decisions made during provisioning and service hardening.

The goal was not to create the most restrictive environment possible.

The goal was to reduce risk while keeping the platform understandable and operational.

Several decisions improved isolation, but some protections were intentionally rejected because security that breaks the service is not useful.

---

# What We Protected Against

This work focused on reducing exposure in five areas:

1. accidental modification of operating system files
2. unnecessary service permissions
3. uncontrolled access between services
4. excessive log growth
5. configuration drift after repeated provisioning

The controls chosen were intended to reduce impact if one service behaves unexpectedly.

---

# Major Decisions

| Decision                 | Problem                                         | Choice                       | Benefit                   | Cost                             |
| ------------------------ | ----------------------------------------------- | ---------------------------- | ------------------------- | -------------------------------- |
| Non-login service users  | Services should not become interactive accounts | Use /usr/sbin/nologin        | Reduced misuse risk       | More administration overhead     |
| Shared application group | Services need limited collaboration             | Create kijanikiosk group     | Controlled sharing        | Group management                 |
| Strict system protection | Services should not write to OS paths           | ProtectSystem=strict         | Reduced accidental change | Required explicit writable paths |
| ACL inheritance          | Rotated files can lose access rules             | Use default ACLs             | Access survives rotation  | More complex permissions         |
| Persistent journal       | Logs should survive reboot                      | Enable persistent journald   | Better investigation      | Storage growth                   |
| Log rotation             | Logs already exceeded safe size                 | Daily rotation + compression | Controlled storage        | Slight operational complexity    |
| Health JSON              | Provisioning status must be observable          | Write health artifact        | Easier verification       | Additional maintenance           |
| Service hardening        | Reduce attack surface                           | Incremental systemd controls | Lower exposure score      | Requires testing                 |

---

# Why Ownership Was Explicit

Ownership decisions were made directory by directory instead of granting broad permissions.

For example:

- API files belong to kk-api
- Payments files belong to kk-payments
- Shared logs belong to kk-logs

This reduced situations where one component could modify another component’s files.

Shared access was granted through groups and ACLs instead of world-readable permissions.

---

# Why Hardening Was Incremental

One of the lessons from this lab was that stronger security settings do not automatically create a safer system.

The payments service started with a moderate exposure score.

Additional restrictions were introduced gradually.

After each change:

- systemd was reloaded
- service startup was tested
- exposure was measured again

This process avoided creating a configuration that looked secure but silently failed.

The final score reached the required target while preserving successful startup.

---

# Decisions That Were Rejected

## PrivateNetwork=true

This would isolate the service from the host network.

That sounds attractive at first.

However, payments systems commonly need outbound communication.

Applying this without validating future requirements could create failures later.

The decision was to leave networking available and document the risk.

---

## Aggressive SystemCall filtering

Very broad syscall filtering can improve security scores quickly.

The downside is that failures may only appear under real application load.

Instead of maximizing restrictions, only lower-risk categories were restricted.

---

# Operational Tradeoffs

Some decisions intentionally accept operational complexity.

Examples:

ACLs require more explanation than simple permissions.

Log rotation requires testing after changes.

Health monitoring introduces another artifact that must remain readable.

These costs were accepted because they support repeatability and recovery.

---

# Honest Gaps

This environment is not production ready.

Several areas remain incomplete.

Examples:

- application code behavior was not validated
- service-to-service communication was not tested
- no secret management system exists
- firewall rules assume known network ranges
- health checks only validate port reachability
- there is no backup strategy
- there is no monitoring dashboard
- no disaster recovery process exists

These gaps do not invalidate the provisioning work, but they would need to be addressed before real deployment.

---

# Conclusion

Security decisions were treated as engineering decisions rather than score targets.

The final environment favors:

- predictable ownership
- explicit permissions
- repeatable provisioning
- measured hardening
- documented tradeoffs

The result is not perfect security.

The result is a configuration that can be explained, reproduced, and improved.
