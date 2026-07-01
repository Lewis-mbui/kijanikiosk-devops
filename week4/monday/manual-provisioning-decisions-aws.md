# Manual Provisioning Decisions - KijaniKiosk API Server (AWS)

| Decision         | Value I chose                   | Reason                                                      |
| ---------------- | ------------------------------- | ----------------------------------------------------------- |
| Cloud provider   | AWS EC2                         | Selected to gain experience with cloud provisioning         |
| Region           | Africa (Cape Town) - af-south-1 | Closest AWS region to Kenya                                 |
| Operating system | Ubuntu Server 24.04.4 LTS       | Closest clean Ubuntu image available                        |
| Instance type    | t3.micro                        | Smallest available option under current account constraints |
| VPC              | Default VPC                     | Existing managed network available                          |
| Subnet           | Auto-selected                   | Sufficient for a single lab VM                              |
| Security group   | kijanikiosk-api-sg              | Explicit firewall policy                                    |
| SSH key pair     | aws-first-key                   | Created for secure SSH authentication                       |
| Root volume size | 8 GiB gp3                       | AWS default root volume                                     |
| Public IP?       | Yes                             | Required for SSH access                                     |
| Tags / labels    | Name: kijanikiosk-api           | Resource identification                                     |

---

## Verification Baseline

### uname -a

- Linux kernel: 6.17.0-1017-aws

### lsb_release -a

- Ubuntu 24.04.4 LTS
- Codename: noble

### df -h

- Root filesystem usable: ~6.8 GB

### free -h

- Memory: ~911 MiB

### ip addr show

- Interface: ens5
- Private IP: 172.31.12.112/20
