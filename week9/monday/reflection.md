# Week 9 Monday Reflection

## Question 1: What specific information did `kubectl describe pod` show that `kubectl get pods` could not, and what did that information tell you that you could not have known from the STATUS column alone?

`kubectl get pods` only gave me the current status of each Pod, such as `ImagePullBackOff`, `CrashLoopBackOff`, or `OOMKilled`. While this immediately showed that something was wrong, it did not explain why the Pod had entered that state.

`kubectl describe pod` provided the detailed information needed to identify the root cause. During the ImagePullBackOff exercise, the Events section showed the exact error message: `manifest for kijanikiosk/kk-payments:tag-does-not-exist not found: manifest unknown`. This confirmed that Kubernetes could reach the registry but the requested image tag did not exist. During the CrashLoopBackOff exercise, the Events showed repeated `Back-off restarting failed container` messages together with a restart count of five, confirming that the container was repeatedly starting and exiting. In the OOMKilled exercise, the Containers section showed `Last State: Terminated`, `Reason: OOMKilled`, and `Exit Code: 137`, proving that the Linux kernel terminated the process because it exceeded its memory limit. None of this information was available from the STATUS column alone.

---

## Question 2: Describe the exact difference in the experience of creating `nginx-imperative` vs `nginx-declarative`. Focus on what happened after deletion: what would you need to recreate each resource? Which approach leaves you in a better position and why?

The imperative Deployment existed only because I had executed the `kubectl create deployment` command. After deleting it, there was no manifest file describing the resource. To recreate it, I would have needed to remember or recover the exact `kubectl create` command, including the image name, replica count, labels, and any other options that had been used.

The declarative Deployment was created from a YAML manifest generated with `--dry-run=client -o yaml`, edited to include the required `week: "9"` label, and then applied using `kubectl apply -f`. Even after deleting the Deployment, I still had the manifest file. Recreating the Deployment only required running `kubectl apply -f` again.

The declarative approach leaves me in a much better position because the desired state is stored in version control, can be reviewed through pull requests, can be recreated after a cluster failure, and does not depend on someone remembering the original command.

---

## Question 3: In the CrashLoopBackOff exercise, what did `kubectl logs --previous` show and what did `kubectl logs` without `--previous` return? Why does this matter in a production incident at 02:00 when the container is crashing every 30 seconds?

In my exercise, both `kubectl logs` and `kubectl logs --previous` returned the same output:

```
kk-payments starting
ERROR: DATABASE_URL not set
```

This happened because every container restart executed the same commands before exiting with status code 1, so both the current and previous container instances produced identical logs.

Although the outputs matched in this controlled exercise, I understood why `--previous` is recommended. During a real production incident, the current container may have only just restarted and may not have produced enough logs before crashing again. The previous container instance often contains the complete error message that caused the crash. Using `kubectl logs --previous` therefore increases the chance of seeing the original failure instead of only the startup messages from the latest restart, making diagnosis much faster when every restart lasts only a few seconds.

---

## Question 4: The Week 4 Ansible playbook is idempotent: running it twice with no changes produces no unexpected effects. Describe what the output was when you applied the `nginx-declarative` manifest a second time with no changes. What does idempotency mean in the context of a CI/CD pipeline that applies manifests on every merge?

When I applied the `nginx-declarative` manifest for the second time without making any changes, Kubernetes reported that the Deployment was **unchanged** rather than producing an error or recreating the resource. This demonstrated that `kubectl apply` compares the declared state in the manifest with the live state of the cluster and only performs work when there is an actual difference.

This is the same principle of idempotency that I used earlier with Ansible, where running the same playbook multiple times resulted in `changed=0` when the servers were already in the desired state. In a CI/CD pipeline, idempotency means that every merge can safely trigger `kubectl apply -f` without worrying about duplicate resources or unintended modifications. If nothing has changed in the manifests, Kubernetes leaves the existing resources untouched. If a change has been committed, Kubernetes reconciles the cluster to match the newly declared desired state.
