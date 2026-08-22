# Restricted Sudo Policy — Amina

Purpose:

Grant operational capability without unrestricted privilege escalation.

Allowed actions:

- restart KijaniKiosk services
- inspect service status
- read service logs
- safely edit nginx configuration

Rules:

```bash
amina ALL=(root) NOPASSWD: \
/usr/bin/systemctl restart kk-api, \
/usr/bin/systemctl restart kk-payments, \
/usr/bin/systemctl restart kk-logs
```

Explanation:
Allows controlled service restarts only.

Avoids:

- arbitrary systemctl usage
- starting unauthorized services
- broad root execution

---

```bash
amina ALL=(root) NOPASSWD: \
/usr/bin/systemctl status kk-api, \
/usr/bin/systemctl status kk-payments, \
/usr/bin/systemctl status kk-logs
```

Explanation:
Allows operational diagnostics only.

Avoids:

- modification operations
- unit creation
- daemon manipulation

---

```bash
amina ALL=(root) NOPASSWD: \
/usr/bin/journalctl -u kk-api, \
/usr/bin/journalctl -u kk-payments, \
/usr/bin/journalctl -u kk-logs
```

Explanation:
Provides log visibility.

Avoids:

- unrestricted journal access
- reading unrelated services

---

```bash
amina ALL=(root) NOPASSWD: sudoedit /etc/nginx/nginx.conf
```

Explanation:
Allows safe configuration editing.

Avoids:

- editor shell escapes
- arbitrary root file modification
