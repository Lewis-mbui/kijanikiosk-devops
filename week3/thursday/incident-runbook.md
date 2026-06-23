## Phase1: Initial hypothesis

I believe the 502 errors are not currently caused by active CPU, memory, or disk resource exhaustion because CPU idle remained above 94%, I/O wait remained near 0%, swap activity was absent, and blocked processes remained at 0. However, the unusually large KijaniKiosk log directory (1.6G) may indicate uncontrolled log growth that could contribute to intermittent degradation. My next step is to inspect service and nginx logs to determine whether application or routing failures explain the 502 responses.

## Phase 2: Revised hypothesis

Performance and log evidence do not currently indicate CPU, memory, disk saturation, or application crashes. kk-payments reported no error-level journal entries, nginx showed no upstream failures, and kernel logs showed no storage errors. However, the absence of a KijaniKiosk logrotate policy combined with approximately 1.6G of accumulated payment logs suggests uncontrolled log growth that may contribute to service instability over time. Since neither performance nor logs explain the 502 responses, the next step is to investigate network state, service listeners, port ownership, and firewall configuration.

## Phase 3: Network Layer Investigation

### Objective

Determine whether network state, service reachability, or listener configuration contributed to intermittent 502 responses from the payments endpoint.

### Commands Executed

```bash
sudo ss -tlnp
ps -p 2624 -o pid,ppid,user,lstart,cmd
curl -sv --max-time 3 http://localhost:3001/
sudo ufw status numbered
ip addr show
curl -sv --max-time 3 http://10.0.2.15:3001/
```

### Findings

#### Finding 1 — Unexpected listener on port 3001

`ss -tlnp` showed TCP port 3001 listening on loopback and owned by a Node.js process:

```text
127.0.0.1:3001
users:(("node",pid=2624))
```

This required additional validation because port 3001 was expected to belong to `kk-payments`.

---

#### Finding 2 — Rogue process identified

Process inspection revealed:

```text
PID: 2624
USER: root
COMMAND: node /tmp/rogue-server.js
STARTED: Mon Jun 22 19:52:35 2026
```

Indicators of abnormality:

- Running as root
- Executing from `/tmp`
- Not managed through systemd
- Name and location inconsistent with expected deployment pattern

---

#### Finding 3 — Incorrect application responding on port 3001

Requesting the backend directly:

```bash
curl http://localhost:3001/
```

returned:

```json
{
  "error": "Internal Server Error",
  "service": "unknown"
}
```

Expected behavior was a valid response from `kk-payments`.

This confirmed requests were reaching an unintended process rather than the intended backend.

---

#### Finding 4 — Firewall policy blocked health checks

`ufw status numbered` showed:

```text
3001/tcp DENY IN Anywhere
# MISCONFIGURED: blocks health checks
```

This rule prevented external access and monitoring visibility to the payments service.

---

#### Finding 5 — External connectivity failed

Testing the external interface:

```bash
curl http://10.0.2.15:3001/
```

resulted in:

```text
Connection refused
```

confirming the service was inaccessible externally.

### Revised Hypothesis

The incident is caused by multiple interacting failures rather than resource exhaustion. A rogue process occupied the expected application port and returned HTTP 500 responses while a firewall deny rule blocked health checks and external reachability. Separately, missing log rotation allowed uncontrolled log accumulation that increases long-term operational risk and could contribute to future I/O degradation.

## Remediation Step 1 — Resolve Port Conflict

Objective: Restore ownership of port 3001 to the intended `kk-payments` service.

Before remediation, port 3001 was occupied by an unexpected Node.js process running from `/tmp/rogue-server.js`.

Actions performed:

```bash id="jv6ehd"
sudo ss -tlnp | grep 3001
sudo kill -TERM <PID>
ps -p <PID>
sudo ss -tlnp | grep 3001
curl http://localhost:3001/
```

Decision rationale:

SIGTERM was selected instead of SIGKILL because graceful termination allows cleanup, connection closure, and resource release. The process exited normally and force termination was not required.

Expected outcome:

Port 3001 becomes exclusively owned by the intended application and requests are routed to `kk-payments` instead of the rogue service.

## Remediation Step 2 — Remove Firewall Misconfiguration

Objective: Restore visibility and connectivity for health checks and monitoring.

Before remediation, UFW contained explicit deny rules for TCP port 3001 for both IPv4 and IPv6.

Actions performed:

```bash
sudo ufw status numbered
sudo ufw delete <rule>
sudo ufw status verbose
```

Decision rationale:

The deny rule prevented monitoring systems and external probes from reaching the application port. Removing the rule restores correct observability and prevents false unhealthy states.

Expected outcome:

Port 3001 is no longer blocked by local firewall policy and health checks can reach the intended backend.
