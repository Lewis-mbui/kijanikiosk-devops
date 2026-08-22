# kk-payments Hardening Log

## Objective

Reduce systemd exposure for kk-payments.service below 2.5 while keeping the service operational.

Validation rule:

Every hardening change must satisfy:

1. service restarts successfully
2. systemd-analyze security score improves or remains acceptable

---

# Baseline

Initial score:

```text
4.9 OK
```

Service state:

```text
active
```

Observation:

The unit already contained strong controls:

- ProtectSystem=strict
- ProtectHome=true
- NoNewPrivileges=true
- ProtectKernelTunables=true
- ProtectControlGroups=true
- ProtectKernelModules=true
- CapabilityBoundingSet=
- MemoryDenyWriteExecute=true
- LockPersonality=true

Largest remaining exposure areas:

- unrestricted namespaces
- unrestricted devices
- unrestricted process visibility
- unrestricted syscall categories

---

# Iteration 1

Changes added:

```ini
PrivateDevices=true
PrivateUsers=true
ProtectKernelLogs=true
ProtectHostname=true
RestrictRealtime=true
RemoveIPC=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
SystemCallArchitectures=native
ProtectProc=invisible
ProcSubset=pid
```

Result:

```text
2.6 OK
```

Service restart:

```text
PASS
```

Reasoning:

This iteration focused on reducing process visibility and namespace escape paths before restricting runtime behavior.

---

# Iteration 2

Changes added:

```ini
SystemCallFilter=~@clock
SystemCallFilter=~@debug
SystemCallFilter=~@module
SystemCallFilter=~@mount
SystemCallFilter=~@obsolete
```

Result:

```text
1.9 OK
```

Service restart:

```text
PASS
```

Reasoning:

Only syscall classes judged low-risk for this service were blocked.

Stopped after reaching the target.

---

# Rejected Directives

## PrivateNetwork=true

Rejected.

Reason:

The payments service may eventually need outbound communication.

This directive could create a misleading security score while silently breaking future integrations.

---

## SystemCallFilter=~@privileged

Rejected.

Reason:

The restriction provides score improvement but carries higher compatibility risk without application workload testing.

---

# Final Unit Characteristics

Final score:

```text
1.9
```

Final state:

```text
service operational
```

Security approach:

- isolate processes
- reduce namespace creation
- reduce kernel interaction
- limit syscall surface
- avoid speculative restrictions

---

# Conclusion

The final configuration achieved the required exposure target while preserving successful startup behavior.

Hardening stopped after meeting requirements instead of maximizing restrictions.
