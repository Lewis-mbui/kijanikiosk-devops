# Integration Notes

## Purpose

Friday combined requirements from multiple earlier labs into a single provisioning system. Several requirements interacted in ways that created conflicts. This document records the conflicts, alternatives considered, and the reasoning behind the final choices.

---

# Challenge A — ProtectSystem=strict and EnvironmentFile

## Conflict

The services were hardened using:

```ini
ProtectSystem=strict
```

At the same time, services required configuration files through:

```ini
EnvironmentFile=
```

A strict filesystem policy can prevent services from accessing configuration if those files are stored in protected locations.

## Options Considered

### Option 1 — Move configuration into writable service directories

Pros:

- simple mental model

Cons:

- mixes configuration with application state

Rejected.

---

### Option 2 — Keep configuration under /opt/kijanikiosk/config and explicitly permit access

Pros:

- preserves separation of concerns
- predictable ownership model

Cons:

- requires careful permission management

Chosen.

## Final Decision

Configuration remained in:

```text
/opt/kijanikiosk/config/
```

Ownership:

```text
root:kijanikiosk
640
```

Services received read access through group membership.

This preserved hardening while keeping configuration external to service code.

---

# Challenge B — Health Check Ownership and Access Model

## Conflict

Phase 7 writes:

```text
/opt/kijanikiosk/health/last-provision.json
```

Provisioning runs as root.

Monitoring users needed read access.

Without explicit ownership the file would not fit the access model.

## Options Considered

### Option 1 — World-readable health directory

Rejected.

Reason:
exposed operational details unnecessarily.

---

### Option 2 — Group-readable monitoring directory

Chosen.

Ownership:

```text
kk-logs:kijanikiosk
```

Permissions:

```text
750
```

File permissions:

```text
640
```

## Final Decision

Health artifacts became readable to operational users while remaining protected from modification.

ACL inheritance was applied where required.

---

# Challenge C — logrotate postrotate and PrivateTmp

## Conflict

Log rotation normally uses:

```text
systemctl reload
```

The logging service used:

```ini
PrivateTmp=true
```

Reload only works if the service implements:

```ini
ExecReload=
```

## Options Considered

### Option 1 — Add ExecReload

Pros:

- conventional approach

Cons:

- unnecessary complexity for current service behavior

Rejected.

---

### Option 2 — Make postrotate tolerant

Chosen.

Implementation:

```bash
systemctl reload kk-logs.service 2>/dev/null || true
```

## Final Decision

Rotation continues even if reload is unsupported.

The access model was verified after forced rotation.

---

# Challenge D — Dirty VM and Package Holds

## Conflict

The provisioning script runs repeatedly.

Pinned package versions and existing installations can conflict.

Blind installation risks accidental downgrade.

## Options Considered

### Option 1 — Always reinstall

Rejected.

Reason:
not idempotent.

---

### Option 2 — Detect drift and fail loudly

Chosen.

Implementation:

- inspect installed version
- compare against pinned version
- skip matching versions
- stop if unexpected drift exists

## Final Decision

The script preserves known-good versions and avoids silent package changes.

---

# Lessons Learnt

Most conflicts were not technical limitations.

They appeared because one correct decision created consequences somewhere else.

The final provisioning design prioritized:

- explicit ownership
- observable health
- controlled hardening
- repeatable execution
- predictable recovery
