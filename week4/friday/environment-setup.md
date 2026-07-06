# Environment Setup

This document records the software environment used to complete the Week 4 Friday Infrastructure as Code pipeline lab.

| Component        | Version          | Notes                         |
| ---------------- | ---------------- | ----------------------------- |
| Operating System | Ubuntu 26.04 LTS | Local development workstation |
| Terraform        | v1.15.7          | Infrastructure provisioning   |
| Ansible          | v2.21.1          | Configuration management      |

## AWS Environment

- Cloud Provider: AWS
- Region: af-south-1 (Cape Town)
- Operating System Image: Ubuntu Server 24.04 LTS
- Infrastructure Provisioning: Terraform
- Configuration Management: Ansible

## Project Structure

The deployment consists of:

- Three EC2 instances:
  - api-staging
  - payments-staging
  - logs-staging
- Modular Terraform configuration
- Ansible playbook with host-specific variables
- Automated deployment pipeline (`pipeline.sh`)

## Validation

The environment was validated using:

- `terraform validate`
- Successful execution of `pipeline.sh`
- Successful Ansible connectivity test
- Idempotent second pipeline run (`changed=0`)
- `systemd-analyze security` score of **1.9** for `kk-payments.service`
