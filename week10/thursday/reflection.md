# Week 10 Thursday Reflection

## Question 1

**In the log analysis exercise, you were told to do the manual analysis before using the AI tool. Explain specifically what risk you would have introduced by running the AI analysis first and reading the manual analysis second, referencing the incident log's scaling event at 02:12:19 and what a plausible AI misinterpretation of that event would look like.**

Doing the AI analysis first would introduce **anchoring and automation-bias risk**. Instead of forming my own hypothesis from the evidence, I could unconsciously interpret the logs through whatever explanation the AI provided. That would make the later "manual" analysis less independent and reduce my ability to detect an AI mistake.

The scaling event at `02:12:19` is a good example. An AI could plausibly see that the replica count increased from three to four and that successful payments later appeared at `02:13:01` and `02:13:44`, then conclude that scaling fixed the incident. Reading the logs manually first showed why that conclusion would be premature. Immediately after scaling, database pool utilisation was still `20/20` with `22` requests waiting, followed by payment failures at `02:12:21` and `02:12:22`.

The real bottleneck shown by the logs was database connection-pool exhaustion, not insufficient application replicas. Our AI analysis ultimately reached the same conclusion and correctly avoided attributing the later recovery to scaling. Because I had already established the manual baseline, I could evaluate that conclusion against the evidence instead of accepting it simply because the AI produced it.

---

## Question 2

**The Jenkins input step has a `submitter` field that restricts who can approve. A new engineer suggests removing this restriction so that "anyone on the team can approve in an emergency." Give two specific reasons why this is a bad idea, referencing both the security principle and the audit trail requirement from Nia's three demands.**

Removing the `submitter` restriction would first violate the **principle of least privilege**. Production deployment approval is a privileged action and should only be available to engineers who have explicitly been authorised to make that decision. Allowing every authenticated Jenkins user to approve would give people authority they may not require as part of their role. An emergency should be handled through a defined emergency-access process rather than permanently weakening the production gate.

Second, removing the restriction would weaken the value of the **approval audit trail**. Nia required the pipeline to show who approved a production deployment, when it was approved, and why. Recording an identity is more useful when that identity can be checked against a known list of authorised approvers. If anyone can approve, the log may prove that someone clicked `Deploy`, but it provides weaker evidence that an appropriately authorised person reviewed the production change.

Keeping a restricted `submitter` list therefore combines accountability with least privilege. The `APPROVAL_REASON` records why the deployment was authorised, while Jenkins records which authorised user actually approved it. This satisfies the requirement for an explicit human production gate without treating every team member as equally authorised to perform a high-risk action.

---

## Question 3

**The AI-generated Terraform snippet used `region = "us-east-1"`. KijaniKiosk processes payment data for East African customers. Identify the specific regulation or data governance principle this region choice potentially violates, and explain what the correct Terraform change is and why it is not just a naming preference but a compliance requirement.**

The governance issue identified in the supplied material is **data classification and residency**. The generated Terraform places the infrastructure in:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

This would place KijaniKiosk payment-receipt infrastructure in a US region even though the workload handles East African payment data. The governance checklist states that resources storing payment or personal data must be placed in the correct region and that data should not cross jurisdictional boundaries without explicit approval.

The appropriate Terraform change for the KijaniKiosk environment is:

```hcl
variable "aws_region" {
  type    = string
  default = "af-south-1"
}

provider "aws" {
  region = var.aws_region
}
```

This is not simply a naming or deployment preference. An AWS region determines the geographical location in which the infrastructure and associated data are hosted. Selecting the wrong region can therefore violate organisational data-residency requirements and potentially create compliance problems for payment data.

The Thursday course material does **not name a specific statute or regulation**, so I would not claim that the snippet violates a particular Kenyan or East African law based solely on the provided material. What the reading explicitly establishes is the **data classification and residency principle**: East African financial data must use the approved region and must not cross jurisdictional boundaries without explicit approval.

---

## Question 4

**Tendo's closing note traces the capability additions from Week 2 to Week 10. Identify three specific cross-week technical dependencies in the KijaniKiosk system as it stands at the end of Thursday: a Week 10 component that depends on a Week N component working correctly, naming what breaks in Week 10 if the Week N component fails. Use concrete component names, not general descriptions.**

### Dependency 1: Week 10 Jenkins Approval Gate → Week 5 CI/CD Pipeline

The Week 10 `Approve Production Deployment` stage depends on the Jenkins CI/CD pipeline developed earlier in the course. The approval gate only has value because it sits between successfully completed pre-production stages and the production deployment action.

The Week 5 pipeline established the build, test, artifact and deployment workflow that the Week 10 approval control now governs. If Jenkins cannot build or test `kk-payments` correctly, the approval gate could be asking a human to approve an artifact that has not actually passed the expected CI checks.

The Week 10 gate therefore does not replace the existing CI/CD controls. It adds another checkpoint before the higher-risk production action.

### Dependency 2: Week 10 Production Approval → Week 9 Kubernetes Deployment

The production deployment protected by the Week 10 approval gate depends on the Kubernetes Deployment and declarative manifests introduced in Week 9.

Thursday's example production stage updates the image reference in:

```text
k8s/kk-payments-deployment.yaml
```

and then runs:

```bash
kubectl apply -f k8s/kk-payments-deployment.yaml
kubectl rollout status deployment/kk-payments
```

If the Week 9 Kubernetes Deployment is invalid, the cluster is unavailable, or the rollout cannot complete successfully, approving the Week 10 Jenkins gate will not result in a successful production deployment.

This also carries forward the Week 9 configuration-drift lesson. Using only `kubectl set image` would change the running cluster without updating the repository manifest. A later `kubectl apply -f` could then restore the old image. The Week 10 pipeline therefore depends on the declarative Kubernetes deployment model established in Week 9.

### Dependency 3: Week 10 AI-Assisted Incident Analysis → Week 9 Operational Troubleshooting and Logging

The Week 10 AI-assisted incident workflow depends on the operational evidence and troubleshooting practices developed in Week 9.

The Thursday incident analysis was possible because `kk-payments` produced useful signals such as:

```text
db.pool.utilisation
db.connection.timeout
payment.failed
```

Those signals allowed both the engineer and the AI assistant to reconstruct the progression from connection-pool pressure to payment failures.

This builds on the manual-first troubleshooting approach used in Week 9 with commands such as:

```bash
kubectl describe pod
kubectl logs
kubectl logs --previous
```

If the application and Kubernetes environment do not expose useful logs and operational evidence, the Week 10 AI assistant has insufficient trustworthy information to analyse. It may still produce a plausible explanation, but that explanation would be much harder for an engineer to verify.

The Week 9 observability and troubleshooting capability is therefore a prerequisite for responsible Week 10 AI-assisted incident analysis: **AI can accelerate analysis of operational evidence, but it cannot replace the evidence itself.**
