## Why No Login Decision?
When creating the services accounts, I assigned them the shell:
```
/usr/sbin/nologin
```
instead of
```
/bin/false
```
to communicate intent if anyone tries to login to the service instead of failing silently
