# Manual Provisioning Decisions - KijaniKiosk API Server

| Decision         | Value I chose                                                       | Reason                                                                                       |
| ---------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Cloud provider   | Multipass (local VM)                                                | Lab allows local VM provisioning while preserving identical infrastructure decisions         |
| Region           | Local host (Nairobi equivalent not applicable for local VM)         | Multipass runs locally and does not require region selection                                 |
| Operating system | Ubuntu 22.04.5 LTS (Jammy)                                          | Required by lab constraints and supported by Multipass image                                 |
| Instance type    | 1 vCPU, 1 GB RAM                                                    | Smallest practical VM size matching lab requirements                                         |
| VPC              | Multipass default virtual network                                   | Multipass automatically manages VM networking                                                |
| Subnet           | 10.139.142.0/24                                                     | Automatically assigned internal network for VM communication                                 |
| Security group   | Default Multipass networking (no explicit inbound rules configured) | Multipass does not expose cloud-style security group controls                                |
| SSH key pair     | Multipass-managed authentication                                    | Multipass automatically provisions SSH access                                                |
| Root volume size | 5 GB requested (~4.8 GB usable)                                     | Lab required default root volume; observed usable capacity differs slightly after formatting |
| Public IP?       | No                                                                  | VM received private IP only (10.139.142.138)                                                 |
| Tags / labels    | Name: kijanikiosk-api                                               | Used to identify the VM purpose                                                              |

## Verification Baseline

### uname -a

- Linux kijanikiosk-api
- Kernel: 5.15.0-185-generic

### lsb_release -a

- Ubuntu 22.04.5 LTS
- Codename: jammy

### df -h

- Root filesystem: ~4.7 GB usable

### free -h

- Memory available: ~951 MiB

### ip addr show

- Interface: ens3
- Internal IP: 10.139.142.138/24
