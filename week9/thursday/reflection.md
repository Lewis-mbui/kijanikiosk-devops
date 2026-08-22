# Week 9 Thursday Reflection

## Lab Analysis Question

**Nia asks: "If the readiness probe on a Pod fails during a high-traffic period, what exactly happens to that Pod? Does it restart? Does traffic stop going to it? Can it recover without a deployment? Walk me through the sequence."**

If the readiness probe on a `kk-payments` Pod fails, Kubernetes marks that Pod as **NotReady**. In our Deployment, the readiness probe calls `GET /health` on port `3001` every 10 seconds after an initial 5-second delay. If the probe fails three consecutive times, the Pod is removed from the Service's usable endpoints.

The container itself does **not** restart because readiness controls traffic routing, not container lifecycle. The `kk-payments-service` simply stops sending new traffic to that Pod while continuing to route requests to the other Ready replicas. Since the Ingress routes to the Service rather than directly to individual Pods, external traffic through `kijani.local/payments/...` continues reaching whichever replicas remain Ready.

The Pod can recover without a new deployment. Kubernetes continues running the readiness probe, and if `/health` starts returning success again, the Pod becomes Ready and is added back to the Service endpoints. A restart would only be triggered if the separate **liveness probe** failed according to its configured threshold.

---

## Question 1

**Explain the difference between a readiness probe failure and a liveness probe failure in terms of what Kubernetes does in response to each, and why a readiness probe failure alone does not trigger a container restart. Give a concrete scenario for kk-payments where you would want readiness to fail but liveness to continue passing.**

A readiness probe determines whether a Pod should receive traffic, while a liveness probe determines whether Kubernetes should restart the container.

In the lab, both probes checked:

`http://<pod>:3001/health`

but they serve different purposes. The readiness probe was configured with a 5-second initial delay and a 10-second period, while the liveness probe used a longer 15-second initial delay and a 20-second period. A readiness failure marks the Pod NotReady and removes it from the `kk-payments-service` endpoints. The process remains running. A liveness failure, after reaching its failure threshold, causes Kubernetes to restart the container.

A concrete `kk-payments` example would be temporary database overload during a busy payment period. The application process may still be healthy and capable of recovering, so restarting it would be unnecessary. However, while its database connection pool is exhausted, it may be unable to safely process requests. Readiness should fail so the Service temporarily stops routing payment requests to that Pod, while liveness should continue passing so the process has an opportunity to recover on its own.

---

## Question 2

**The Ingress manifest did not change when you scaled from 3 to 6 replicas. Explain why, referencing the relationship between the Ingress object, the Service, and the Pod endpoints. What is the role of the Service in this architecture, and what would have broken if you had configured the Ingress to route directly to Pod IPs instead?**

The Ingress did not need to change because it does not know or care how many `kk-payments` Pods exist. Our routing path was effectively:

`Ingress -> kk-payments-service -> Ready kk-payments Pods`

The `kijani-ingress` resource routed `/payments` traffic to `kk-payments-service` on port `3001`. The Service then selected Pods using the `app: kk-payments` label. When the Deployment scaled from 3 replicas to 6, Kubernetes automatically added the new Ready Pods to the Service endpoints after their readiness probes passed.

This is why the same Ingress continued working during the scale-up without modification.

The Service provides a stable network identity and hides the changing set of Pod IP addresses behind it. If the Ingress had been configured directly against Pod IPs, the configuration would become stale whenever Pods were created, deleted, restarted, or replaced during a rolling update. Pod IPs are temporary. Using a Service allows the Ingress to reference one stable backend while Kubernetes continuously maintains the actual endpoint list.

---

## Question 3

**You set `requests.cpu: 100m` and `limits.cpu: 500m` on kk-payments. At 6 replicas, what is the total CPU reservation on the cluster, and what is the maximum CPU the kk-payments Deployment is permitted to consume? If your Minikube node has 2 CPUs, what is the maximum number of kk-payments replicas the scheduler would place before any new Pods became Pending?**

Each `kk-payments` Pod requests `100m`, or 0.1 CPU. At 6 replicas, the total CPU reservation is:

`6 × 100m = 600m`

Therefore, the scheduler reserves **600m, or 0.6 CPU**, for the six replicas.

Each Pod also has a CPU limit of `500m`. At six replicas, the theoretical maximum CPU consumption allowed for the Deployment is:

`6 × 500m = 3000m`

which is **3 CPU cores**. On a node with only 2 CPUs, the Deployment obviously cannot physically consume 3 CPUs simultaneously; the containers would compete for available CPU and Kubernetes would throttle them according to their limits.

Scheduling, however, is based primarily on **requests**, not limits. With each Pod requesting `100m`, a node with 2 CPUs, or `2000m`, could theoretically fit:

`2000m ÷ 100m = 20 replicas`

before the CPU requests alone prevented another Pod from being scheduled.

In a real Minikube node, the practical number would be lower because Kubernetes system components and other workloads also consume part of the node's allocatable CPU. The value of 20 assumes the full 2 CPUs were available only to `kk-payments`.

---

## Question 4

**Tendo mentioned HPA requires resource requests to be defined. Explain the causal relationship: why can Kubernetes not calculate CPU utilisation percentage for an HPA target if the Pod has no resource requests set? What specific value would be missing from the metrics the HPA controller reads?**

The Horizontal Pod Autoscaler calculates CPU utilisation as a percentage relative to each container's requested CPU. The request provides the baseline against which measured CPU usage can be compared.

For example, our `kk-payments` containers request `100m` CPU. If a Pod were currently using `70m`, that could be interpreted as approximately 70% of its requested CPU. An HPA configured with a target such as 70% could then decide whether the Deployment should scale up or down.

Without `requests.cpu`, Kubernetes may still obtain the Pod's actual CPU usage from metrics-server, but it has no requested CPU baseline with which to calculate the utilisation percentage. The missing value is therefore the container's **CPU request**.

This is why the Thursday setup required both metrics-server and resource requests before discussing HPA. Metrics-server supplies the observed CPU usage, while `requests.cpu` supplies the denominator needed to turn that usage into a utilisation percentage that the HPA controller can evaluate.
