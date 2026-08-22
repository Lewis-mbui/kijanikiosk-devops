# KijaniKiosk Service Level Objectives

## kk-api (API Service)

### SLIs

1. **Availability SLI:** Measures the proportion of requests to the kk-api service that receive a successful `2xx` HTTP response. It is collected from the Nginx access log by dividing the number of `2xx` responses by the total number of requests during the measurement window.

2. **Latency SLI:** Measures the response time experienced by users, using the 95th percentile (`p95`) so that at least 95% of requests must complete within the target time. It is collected from request-duration values recorded in the Nginx access log and calculated across all requests to the API.

3. **Error rate SLI:** Measures the proportion of requests to `/api/` endpoints that return a server-side `5xx` response. It is collected from the Nginx access log by dividing the number of `5xx` responses for `/api/` paths by the total number of requests to those paths.

### SLOs

| SLI          | Target                                              | Window          | Error budget                                                                 |
| ------------ | --------------------------------------------------- | --------------- | ---------------------------------------------------------------------------- |
| Availability | At least 99.9% of requests receive a `2xx` response | Rolling 30 days | Up to 0.1% unsuccessful availability, equivalent to 43.2 minutes of downtime |
| Latency      | At least 95% of requests complete within 500 ms     | Rolling 30 days | Up to 5% of requests may take longer than 500 ms                             |
| Error rate   | Fewer than 0.5% of `/api/` requests return `5xx`    | Rolling 30 days | Up to 5 server errors per 1,000 API requests                                 |

### Rollback threshold justification

The post-deployment monitor uses tighter short-term thresholds than the long-term SLOs because its purpose is to identify a faulty release before it consumes a meaningful portion of the monthly error budget.

Three consecutive health-check failures trigger rollback after approximately 15 seconds because the monitor polls every five seconds. Fifteen seconds represents approximately 0.006% of a 30-day period, which is far below the 43.2 minutes of downtime permitted by the 99.9% availability SLO. The rollback threshold is therefore much more conservative than waiting for the availability SLO itself to be breached.

The monitor allows a maximum of two errors in a ten-poll window. Because the script checks whether the count is greater than two, the third error triggers rollback. This is stricter than the long-term API error-rate SLO because a new deployment producing several errors within a short confidence window is strong evidence that the release is unhealthy.

The two-second latency threshold is numerically higher than the 500 ms `p95` latency objective. This is intentional because the monitor measures individual requests to the lightweight `/health` endpoint rather than calculating a percentile across normal user traffic. A health request taking more than two seconds repeatedly indicates severe degradation and justifies rollback, while ordinary latency performance should still be evaluated separately against the 500 ms `p95` SLO.

---

## kk-payments (Payments Service)

### SLIs

1. **Availability SLI:** Measures the proportion of requests to the payments service that receive a successful `2xx` response. It is collected from the service or proxy access logs by dividing successful responses by the total number of payment-service requests.

2. **Latency SLI:** Measures how long payment requests take from the client’s perspective, using the 95th percentile (`p95`). It is collected from request-duration values recorded for payment endpoints and calculated over the measurement window.

3. **Payment transaction error rate SLI:** Measures the proportion of requests to `/api/payments` that return a `5xx` response and therefore fail because of a server-side problem. It is collected by dividing the number of `5xx` responses on `/api/payments` by the total number of payment transaction requests.

### SLOs

| SLI                            | Target                                                  | Window          | Error budget                                                  |
| ------------------------------ | ------------------------------------------------------- | --------------- | ------------------------------------------------------------- |
| Availability                   | At least 99.9% of requests receive a `2xx` response     | Rolling 30 days | Up to 43.2 minutes of downtime                                |
| Latency                        | At least 95% of payment requests complete within 500 ms | Rolling 30 days | Up to 5% of payment requests may take longer than 500 ms      |
| Payment transaction error rate | Fewer than 0.1% of payment requests return `5xx`        | Rolling 30 days | No more than 1 server-side failure per 1,000 payment requests |

### Rollback threshold justification

The payments service has a stricter error-rate objective than the general API because a failed payment has a direct business and customer impact. Allowing fewer than 0.1% of payment transactions to return `5xx` means that no more than one transaction in every 1,000 should fail because of the service.

A deployment that causes three consecutive failed health checks would be rolled back after approximately 15 seconds. This is substantially earlier than the point at which the 99.9% monthly availability objective would be exhausted. The monitor therefore protects the payment service’s error budget by stopping a clearly unhealthy release before it can remain active long enough to affect many transactions.

The short monitoring window is deliberately more sensitive than the 30-day SLO measurement window. SLOs describe acceptable steady-state reliability over time, while rollback thresholds answer a narrower question: whether the newly deployed version is safe enough to remain live.

The two-second health-check threshold does not replace the 500 ms `p95` payment latency SLO. It detects severe immediate degradation during deployment, while the percentile SLO measures the experience of users across normal payment traffic. Together, they provide early deployment protection and longer-term reliability measurement.
