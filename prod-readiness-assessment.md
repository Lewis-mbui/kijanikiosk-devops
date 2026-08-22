# Production Readiness Assessment

## External Routing

The current Ingress setup is functional but not yet suitable for real production payment traffic. External requests reach `kijani.local` through the nginx Ingress controller and are routed by path to either `kk-payments` or `kk-api`, which is the correct architectural pattern. However, the traffic is still plain HTTP. Because `kk-payments` handles payment-related credentials and sensitive data, the absence of TLS means traffic could be intercepted or modified in transit. Production should add a Kubernetes TLS Secret containing the certificate and private key, reference it under the Ingress `spec.tls` section, and configure the nginx controller to redirect HTTP to HTTPS, for example with `nginx.ingress.kubernetes.io/ssl-redirect: "true"`.

TLS is not the only gap. The public payment endpoint should also have request controls such as rate limiting to reduce abuse or accidental overload. nginx Ingress supports annotations such as `nginx.ingress.kubernetes.io/limit-rps` for request-rate limits. Authentication or an API gateway layer would also be required before exposing sensitive payment operations publicly.

## Health Signalling

The current readiness and liveness probes are a strong baseline because Kubernetes now checks the actual `/health` endpoint rather than assuming that a running container is ready. The readiness probe prevents traffic from reaching unhealthy Pods, while the liveness probe allows Kubernetes to restart containers that remain stuck.

For production, the probe thresholds should be based on measured startup and dependency behaviour rather than fixed lab values. `initialDelaySeconds: 5` for readiness is acceptable only if the service reliably becomes healthy within that period. The liveness delay should remain comfortably longer than normal startup time. A failure threshold that is too low would be risky during temporary database latency: Kubernetes could remove or restart multiple otherwise recoverable payment Pods during a short dependency slowdown, reducing capacity exactly when load is high.

## Capacity

Three replicas with manual scaling is not sufficient for predictable end-of-month spikes. Production should use a Horizontal Pod Autoscaler once `metrics-server` is available, resource requests remain defined, and an HPA target is configured. The HPA could scale between a safe minimum and maximum replica count based on CPU utilisation.

The CPU target must be tuned carefully. If it is set too high, scaling happens too late and Pods may become overloaded before new replicas appear, increasing latency or errors. If it is set too low, the Deployment may scale unnecessarily, wasting cluster capacity and increasing cost. HPA therefore needs realistic requests, reliable metrics, and production load testing before it can be considered safe.
