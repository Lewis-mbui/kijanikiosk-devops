# KijaniKiosk Access Model

## Objective

The objective of this access model is to enforce least privilege across the KijaniKiosk services while still allowing controlled collaboration where required.

Design decisions prioritize:

- Service isolation
- Protection of secrets
- Controlled sharing
- Prevention of privilege escalation
- Operational support access

## Directory Access Decisions

| Path                         | Owner       | Group       | Mode                      | ACL                   | Reasoning                                                                                                                                               |
| :--------------------------- | :---------- | :---------- | :------------------------ | :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------ |
| /opt/kijanikiosk/api         | kk-api      | kk-api      | 750                       | None                  | API service should control its own files. Other users must not modify or inspect application internals.                                                 |
| /opt/kijanikiosk/payments    | kk-payments | kk-payments | 750                       | None                  | Payment processing contains sensitive business logic and should remain isolated.                                                                        |
| /opt/kijanikiosk/logs        | kk-logs     | kk-logs     | 750                       | None                  | Log aggregation service exclusively manages its working directory.                                                                                      |
| /opt/kijanikiosk/config      | root        | kijanikiosk | Directory: 750 Files: 640 | User read ACL         | Configuration contains secrets and must not belong to application accounts. Root owns configuration while trusted services access via group membership. |
| /opt/kijanikiosk/shared/logs | kk-logs     | kk-logs     | 2770                      | Service-specific ACLs | Shared location requiring collaboration while preserving ownership consistency through SGID.                                                            |

## Permission Reasoning

## Mode 750

Used for service directories.

Owner:

- read
- write
- execute

Group:

- read
- execute

Others:

- denied

This prevents unrelated users from traversing or modifying application files.

## Mode 640

Used for configuration files.

Owner:

- read
- write

Group:

- read

Others:

- denied

**Secrets remain protected from general system users.**

## Mode 2770 (SGID)

Used for shared logs.

The **SGID** bit ensures new files inherit the directory group instead of the creator’s primary group.

### Benefits:

- consistent ownership
- predictable collaboration
- reduced permission drift

## ACL Decision

ACLs were selected only where `chmod` cannot express the required access pattern.

Examples:

- kk-api requires write access to shared logs
- kk-payments requires read access only
- operational user requires controlled read access

ACLs avoid expanding traditional group permissions beyond necessity.

## Security Outcome

This design limits blast radius if a service is compromised while preserving operational visibility and collaboration where required.
