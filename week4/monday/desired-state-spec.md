# KijaniKiosk API Server - Desired State Specification

## Identity

- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: amina

## Compute

- Provider: Multipass (local VM baseline)
- Region: local-host
- Instance type: 1 vCPU, 1 GB RAM
- Operating system: ubuntu-22.04-lts
- Exact image ID: 070de108b25d

Note:
The exact image identifier should not be hardcoded in Terraform. On Tuesday this becomes a dynamic image lookup (data source).

## Networking

- VPC: Multipass default virtual network
- Subnet: 10.139.142.0/24
- Assign public IP: no

## Access Control

- SSH access: enabled (Multipass-managed access)
- HTTP access: not enabled
- All other inbound: deny by default
- All outbound: allow

## Storage

- Root volume: 5 GB requested (~4.8 GB usable)
- Storage type: default Multipass virtual disk

## Authentication

- SSH key pair name: Multipass-managed credentials

## What must NOT exist on this server after provisioning

- No default password authentication
- No unnecessary services listening except sshd
- No world-writable directories outside /tmp
- No public IP assignment
- No additional users created automatically

## Open questions (things that will need decisions before Terraform can encode this)

- Should networking later become an explicit VPC resource?
- Should security controls move into firewall rules or provider security groups?
- Should SSH authentication remain provider-managed or use explicit key definitions?
- Should environment values become variables?
- What image selection rule should Terraform use instead of a fixed image identifier?

## Hardest Decision and Why

The hardest decision during manual provisioning was networking and access control. Multipass abstracts networking and authentication, so many decisions that would normally be explicit in a cloud console were created automatically. That made it difficult to determine which values belong in the desired-state specification and which are implementation details. The exercise highlighted that declarative infrastructure requires intentionally specifying networking and access requirements instead of relying on provider defaults.
