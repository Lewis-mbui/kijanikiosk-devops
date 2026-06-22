# KijaniKiosk API Server - Triage Report

**Date:** 2026-06-21
**Investigated by:** Lewis
**Server:** lewis-HP-EliteBook-840-G8-Notebook-PC
**Incident start (approximate):** 2024-01-15 04:07 based on application log timeline

## Summary

An investigation was performed in response to increased API latency (P95 increasing from approximately 120ms to 480ms). At investigation time, CPU, memory, disk capacity, and HTTP responsiveness appeared healthy. Historical application logs indicate that the degradation likely originated from database-side resource pressure rather than host-level exhaustion.

The strongest evidence suggests database connection pool saturation leading to request queuing, query timeouts, memory pressure warnings, and eventual database connection failures.

---

## Process and Resource State

Observed top memory consumers:

1. chrome (PID 6443) — ~535 MB RSS
2. python3 memory consumer (PID 12744) — ~524 MB RSS
3. GNOME desktop services

Findings:

* No zombie processes detected.
* CPU remained mostly idle (~87% idle).
* System memory was healthy:

  * Total: 14 GiB
  * Available: 9.8 GiB
  * Swap usage: 0 B
* Memory consumer process existed but did not create host-level memory exhaustion.

Conclusion:

No evidence that OS-level CPU or memory pressure caused API degradation.

---

## Filesystem and Disk

Filesystem observations:

* Root partition utilization: 29%
* No partitions exceeded the 80% threshold.

Unexpected files:

* `/var/log/kijanikiosk/access.log.1` ≈ 271 MB
* `/var/log/kijanikiosk/app.log` ≈ 776 B

The access log strongly suggests retained rotated logs or simulated log rotation failure.

Conclusion:

Disk capacity was healthy and unlikely to explain latency, although log growth represents operational risk.

---

## Log Analysis

Timeline observed:

03:45 — Database pool reached 85% utilization
04:01 — Database pool reached 94% utilization
04:07 — Connection pool exhausted
04:08 — Query timeouts began
04:09 — Memory warning recorded
06:22 — Database connection failures (ECONNREFUSED) began

Patterns:

* Database-related events clustered over time.
* Query timeout events appeared immediately after pool exhaustion.
* Retry attempts failed until connection failure was recorded.

System logs did not show evidence of OOM kills or disk failures.

Conclusion:

Database-side degradation appears to be the strongest explanatory signal.

---

## Network and Service State

Observed:

* Port 80 listening.
* No listeners observed on 3000, 8080, or 5432.

HTTP tests:

* `/` → HTTP 200 (~2 ms)
* `/api/health` → HTTP 404

TCP state summary:

* 9 established
* 5 listening

Conclusion:

Web entrypoint remained available. No evidence of connection saturation.

---

## Assessment

Most likely root cause:

Database connection pool saturation caused increasing request latency, eventually producing query timeouts and failed connection attempts.

Host-level resource exhaustion was not supported by the evidence collected.

Secondary observations include abnormal log accumulation and a non-critical memory consumer process.

---

## Recommended Next Steps

1. Investigate database availability, connection pool configuration, and query performance.
2. Implement alerting for connection pool utilization and query timeout thresholds.
3. Configure and verify log rotation and retention policies.
