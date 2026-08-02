# Week 8 Thursday Reflection

## Question 1: The Declarative Model and kubectl apply

When I ran `kubectl apply -f kk-payments-deployment.yaml`, Kubernetes stored the Deployment as the desired state for the application. If a colleague runs the same `kubectl apply` command thirty minutes later without changing the manifest, Kubernetes compares the manifest with the current cluster state and finds that they already match. Because the desired state has already been achieved, no Pods are recreated, no ReplicaSet changes, and the running workload continues uninterrupted. The command reports that the Deployment is unchanged because the reconciliation loop determines that no action is required.

If only the `replicas` field is changed from `2` to `3` and the manifest is applied again, Kubernetes detects that the desired state has changed. The Deployment controller updates the Deployment specification, the associated ReplicaSet increases its desired replica count from two to three, and the scheduler places a new Pod onto a suitable node if sufficient resources are available. The kubelet then starts the container, resulting in three running Pods. This process typically completes within a few seconds on a healthy Minikube cluster and demonstrates the reconciliation loop: Kubernetes continuously compares the actual state with the declared state and automatically makes only the changes required to bring the cluster into agreement.

## Question 2: Resource Requests, Limits, and the Scheduler

The Deployment specifies resource requests of 64Mi memory and 100m CPU, with limits of 256Mi memory and 500m CPU. These values guide both scheduling decisions and runtime resource enforcement.

If a kk-payments Pod attempts to allocate 300MB of memory during a spike in payment processing, it exceeds its configured memory limit of 256Mi. Kubernetes terminates the container with an **OOMKilled** event, and because the Pod is managed by a Deployment, the Deployment controller creates a replacement Pod automatically to restore the desired replica count.

If I increase the Deployment from two replicas to three while the Minikube node has only 100MB of unallocated memory, the scheduler evaluates the new Pod's resource request before placing it. Since the node cannot guarantee the requested resources, the new Pod remains in the **Pending** state until sufficient resources become available or another suitable node exists.

If I deploy another workload without resource requests and it begins consuming all available memory, Kubernetes treats that workload with lower scheduling guarantees. Under memory pressure, the kubelet begins **evicting** Pods according to Kubernetes eviction policies. Workloads without resource requests are more likely to be evicted than workloads with defined requests and limits because they have weaker scheduling guarantees. The resource requests and limits on kk-payments therefore help protect it from resource starvation caused by less constrained workloads.

## Question 3: The Service Selector and the Deployment Update

During Friday's rolling update, the Deployment will gradually replace Pods running image version 1.0.0 with Pods running version 1.1.0. Throughout this transition, both old and new Pods continue to have the label `app: kk-payments`, which matches the selector used by `kk-payments-service`.

Because the Service routes traffic based only on labels, it temporarily distributes requests to both the v1.0.0 and v1.1.0 Pods while they coexist during the rolling update. This is expected behaviour and is different from the Week 7 rolling deployment discussion because Kubernetes intentionally controls this overlap using the Deployment strategy. Rather than switching all traffic manually, the Deployment gradually replaces Pods while ensuring enough healthy replicas remain available.

The number of old and new Pods that run simultaneously is controlled by the Deployment's **RollingUpdate** strategy. In my deployment, `maxUnavailable` was 25% and `maxSurge` was 25%, allowing Kubernetes to create new Pods while only taking a limited number of existing Pods offline at a time. This ensures that the Service always has healthy endpoints available throughout the update.

## Question 4: Kubernetes vs Week 7 Deployment Model

After completing this week's lab, I can clearly see what Kubernetes provides beyond the Week 7 deployment model. During Phase 4, I deleted one of the running kk-payments Pods, yet the application continued serving requests because the second replica remained available while Kubernetes automatically created a replacement Pod. My recorded self-healing time was approximately **35 seconds** from Pod deletion (T0) until the replacement Pod was confirmed running (T1). No manual intervention was required beyond deleting the Pod.

In Week 7, high availability was achieved through the blue/green deployment model. An engineer explicitly switched traffic between two complete environments using nginx and could manually roll back almost immediately by switching traffic back if the new version failed. That provided a very fast rollback mechanism but depended on pre-deployed environments and a deliberate operational action.

This week's Kubernetes Deployment automatically maintained the desired number of replicas and recovered from failures without any manual rollback or restart procedure. However, one capability from Week 7 is not yet addressed in Thursday's lab: **controlled external traffic management**. We currently expose the application using a NodePort Service for development purposes. The production-style ingress routing, external load balancing, and controlled traffic management are introduced in the following week's work.
