# KijaniKiosk API Server - Desired State Specification (AWS)

## Identity

- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: amina

## Compute

- Provider: AWS EC2
- Region: af-south-1 (Africa - Cape Town)
- Availability Zone: af-south-1a
- Instance type: t3.micro
- Operating system: ubuntu-24.04-lts
- Exact image ID: selected dynamically during provisioning (do not hardcode)

Note:
The AMI should be discovered dynamically in Terraform using a data source instead of embedding a fixed image ID.

## Networking

- VPC: vpc-098fc9161773f9db2
- Subnet: auto-selected within selected Availability Zone
- Assign public IP: yes
- Private IP allocation: dynamic

## Access Control

- SSH access:
  - Protocol: TCP
  - Port: 22
  - Source: current client IP only (/32)

- HTTP access:
  - Protocol: TCP
  - Port: 80
  - Source: 0.0.0.0/0

- All other inbound:
  - deny

- All outbound:
  - allow

## Storage

- Root volume:
  - Size: 8 GiB
  - Type: gp3

## Authentication

- SSH key pair name: aws-first-key

## Verification Baseline

- Instance ID: i-036d747dd88fbc95f
- Public IPv4: 13.244.65.107
- Private IPv4: 172.31.12.112

## What must NOT exist on this server after provisioning

- No password-based SSH login
- No inbound access other than approved ports
- No database software installed unintentionally
- No public administrative interfaces
- No world-writable directories outside /tmp
- No unnecessary running services

## Open questions (things that will need decisions before Terraform can encode this)

- Should subnet selection remain automatic?
- Should public IP assignment exist in all environments?
- Should security group rules become reusable modules?
- Should AMI selection use owner filters and image naming conventions?
- Should SSH access become temporary instead of permanent?

## Hardest Decision and Why

The hardest decision during manual provisioning was selecting the operating system image. The original lab requested Ubuntu 22.04, but the available options in the selected AWS region included either newer Ubuntu releases or images bundled with additional software. Choosing between strict specification compliance and a cleaner infrastructure baseline highlighted that infrastructure definitions must encode intent explicitly instead of relying on provider defaults.
