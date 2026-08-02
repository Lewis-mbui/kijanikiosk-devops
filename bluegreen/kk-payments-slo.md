# KijaniKiosk Payments Service Level Objectives

## Purpose

This document defines proposed reliability targets for the `kk-payments` service. These targets have not yet been validated against production traffic and should be reviewed once real traffic and failure data are available.

## Service Level Indicators

### 1. Availability

The availability indicator measures the percentage of payment-service requests that receive a successful `2xx` response.

The data source is the Nginx access log. It is calculated as:

```text
successful 2xx responses
------------------------- × 100
total payment requests
```

The indicator is calculated over a rolling 30-day measurement window.

### 2. Latency

The latency indicator measures the percentage of payment requests completed within 500 milliseconds, using the 95th percentile to represent typical user experience while excluding a small number of extreme responses.

The data source is request-duration data from Nginx access logs or a future metrics platform. The 95th-percentile response time is calculated continuously over a rolling 30-day window.

### 3. Payment Transaction Error Rate

The payment transaction error-rate indicator measures the percentage of requests to `/api/payments` that return a server-side `5xx` response.

The data source is the Nginx access log. It is calculated as:

```text
5xx responses from /api/payments
-------------------------------- × 100
total requests to /api/payments
```

The indicator is calculated over a rolling 30-day measurement window.

## Service Level Objectives

| SLI                            | Proposed target                                                     | Window          | Error budget                                                                 |
| ------------------------------ | ------------------------------------------------------------------- | --------------- | ---------------------------------------------------------------------------- |
| Availability                   | At least 99.9% of payment-service requests receive a `2xx` response | Rolling 30 days | Up to 0.1% unsuccessful availability, equivalent to 43.2 minutes of downtime |
| Latency                        | At least 95% of payment requests complete within 500 ms             | Rolling 30 days | Up to 5% of requests may exceed 500 ms                                       |
| Payment transaction error rate | Fewer than 0.1% of `/api/payments` requests return `5xx`            | Rolling 30 days | No more than 1 server-side failure per 1,000 payment requests                |

## Automated Rollback Thresholds

| SLI                | Short-window rollback threshold                                          | Relationship to the SLO                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Availability       | Three consecutive failed health checks at five-second intervals          | Triggers rollback after approximately 15 seconds, far earlier than the 43.2-minute monthly availability budget is consumed                       |
| Latency            | Three responses slower than 2 seconds within the recent five-poll period | Detects severe immediate degradation; it is intentionally different from the 500 ms 95th-percentile steady-state objective                       |
| Payment error rate | More than two failed checks in a ten-poll window                         | The third error triggers rollback, preventing a faulty release from remaining live long enough to threaten the 0.1% monthly error-rate objective |

The rollback thresholds are intentionally more conservative than the long-term objectives. An SLO measures acceptable reliability over 30 days, while the deployment monitor decides whether a newly released version is safe enough to remain active during its first minute or two.

The availability threshold does not wait for the 99.9% objective to be breached. It reacts after three consecutive failures because repeated failures immediately following a deployment are strong evidence that the new version caused the problem.

The two-second latency threshold is higher than the 500 ms service objective because the monitor checks individual `/health` responses rather than calculating the 95th percentile of real payment traffic. It is intended to detect severe deployment degradation, not replace normal latency monitoring.

## What We Do Not Commit To

### Individual request completion time

The service does not guarantee that every individual payment request will complete within 500 milliseconds. The latency objective applies to the 95th percentile over the measurement window, allowing a limited number of slower requests.

### Client-side or third-party failures

The payment error-rate objective does not include failures caused by invalid client requests, unavailable customer networks, or outages in external payment providers. These events should still be measured separately because they affect customers, but they are not fully controlled by `kk-payments`.

### Server resource utilisation

The service does not commit to a fixed processor or memory utilisation percentage. Resource usage is an operational diagnostic metric rather than a direct measure of the outcome experienced by customers.
