### Systemd Security Analysis

Service:
kk-api.service

Observed hardening:

- NoNewPrivileges=true
- PrivateTmp=true
- ProtectSystem=strict
- ProtectHome=true
- CapabilityBoundingSet=

Additional hardening discussion:

`ProtectSystem=strict`

Prevents modification of most filesystem locations.
The only writable exception is shared/logs.

`CapabilityBoundingSet=`

Drops Linux capabilities so the service cannot perform privileged operations even if compromised.

Conclusion:
The unit significantly reduces attack surface and follows least privilege principles.
