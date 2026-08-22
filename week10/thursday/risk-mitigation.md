# Week 10 Thursday — AI Risk Mitigation

## Phase 3: Risk Mitigation Documentation

Following the governance review of the AI-generated Terraform module, the two most serious risks identified were:

1. A hardcoded production database password.
2. An overly permissive S3 IAM policy.

The following entries document the likelihood, potential impact, required mitigation, and residual risk for each issue.

---

## Risk 1: Hardcoded Production Database Password

**Risk:**  
The Terraform module hardcodes the production database password as:

```hcl
DB_PASSWORD = "kijani-prod-password-2024"
```

This exposes a sensitive production credential directly in the infrastructure source code.

**Likelihood: High**

If the Terraform file is committed to the repository, the password becomes part of Git history and could also appear in pull requests, code review systems, repository backups, or other systems that process the source code. Because the secret is already present as plaintext in the generated module, accidental exposure is highly likely if the code is used without review.

**Impact:**  
If the credential is exposed, an unauthorised user could potentially gain access to KijaniKiosk's production database. This could result in disclosure, modification, or loss of payment-related data and could create additional compliance and operational consequences.

**Mitigation:**  
In the `aws_lambda_function.receipt_processor` resource, replace:

```hcl
DB_PASSWORD = "kijani-prod-password-2024"
```

with:

```hcl
DB_PASSWORD = var.db_password
```

Declare the variable as sensitive:

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

The deployment workflow must then provide the password from an approved external secret source such as AWS Secrets Manager or, where appropriate for the workflow, a controlled `.tfvars` file excluded from Git using `.gitignore`.

The plaintext password must not be committed to the repository. If the credential has already been committed or otherwise exposed, it should also be rotated rather than simply removed from the latest version of the file.

**Residual risk:**  
The application still requires access to the database credential at runtime. Incorrect IAM permissions, secret-store configuration, or Terraform state handling could still expose sensitive information. Access to the secret must therefore remain restricted and auditable even after it has been removed from the source code.

---

## Risk 2: Overly Permissive S3 IAM Policy

**Risk:**  
The `aws_iam_role_policy.receipts_processor_policy` resource grants the receipt-processing Lambda unrestricted S3 permissions through:

```hcl
Action   = ["s3:*"]
Resource = ["*"]
```

This gives the function substantially more access than it requires.

**Likelihood: Medium**

The excessive permissions exist immediately if this policy is deployed. Exploiting them would generally require a vulnerability in the Lambda function, compromised Lambda credentials, or another actor capable of assuming or using the role. The permission itself therefore creates a significant attack path even though exploitation is not guaranteed.

**Impact:**  
If the Lambda function or its credentials were compromised, an attacker could potentially perform S3 operations beyond the receipt-processing workload. Depending on other account controls, this could allow unrelated S3 data to be read, modified, or deleted and significantly increase the blast radius of the compromise.

**Mitigation:**  
In the `aws_iam_role_policy.receipts_processor_policy` resource, replace:

```hcl
Action   = ["s3:*"]
Resource = ["*"]
```

with only the operations required by the receipt processor and scope them to the specific receipt objects.

For example, if the processor only needs to read receipt objects:

```hcl
Statement = [{
  Effect = "Allow"

  Action = [
    "s3:GetObject"
  ]

  Resource = [
    "${aws_s3_bucket.payment_receipts.arn}/*"
  ]
}]
```

If the processor genuinely requires another operation such as `s3:PutObject`, that permission should be added explicitly and scoped to the exact destination bucket or prefix where writes are required rather than restoring `s3:*`.

This applies the principle of least privilege by limiting both the actions the Lambda can perform and the resources against which those actions can be performed.

**Residual risk:**  
The Lambda must retain legitimate S3 permissions to perform its work. If the function is compromised, an attacker could still misuse those permitted actions against the receipt bucket. The remaining risk should therefore be reduced through audit logging, monitoring, restricted role trust policies, and periodic IAM permission reviews.

---

## Conclusion

Both risks demonstrate why AI-generated infrastructure code must not be applied blindly.

The hardcoded database password could expose a production credential through normal source-control workflows, while the wildcard IAM policy unnecessarily increases the blast radius of a compromised function.

The required mitigations are concrete changes to the Terraform configuration rather than simply relying on an AI tool to declare the code safe. After remediation, the changes should still pass human code review, the complete governance checklist, and the production approval gate before deployment.
