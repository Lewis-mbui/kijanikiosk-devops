# Service Account Login Policy Decision

## Decision

Service accounts use:

```
usr/sbin/nologin
```

instead of:

- /bin/false
- locked interactive accounts

## Reasoning

Service accounts exist to run processes and should not support interactive login.

Examples:

- kk-api
- kk-payments
- kk-logs

These accounts should never receive shell access through SSH, local login, or terminal sessions.

## Why /usr/sbin/nologin

When a login attempt occurs:

1. Authentication succeeds if credentials are valid.
2. The shell configured in /etc/passwd is executed.
3. /usr/sbin/nologin immediately terminates the session.
4. A human-readable message is displayed.

Typical behavior:

"This account is currently not available."

This communicates intentional denial rather than appearing broken.

## Why Not /bin/false

/bin/false immediately exits with a failure code

Differences:

- no explanatory message
- less clear operationally
- intended as a generic failure utility rather than
- an account policy tool

Although both prevent shell access, nologin better communicates administrative intent.

## Why Not Locked Interactive Accounts

Locking passwords alone does not guarantee the account cannot execute a shell under every access mechanism.

Disabling the shell directly removes the execution path entirely.

## Security Benefit

Using nologin:

- prevents accidental service logins
- reduces attack surface
- separates machine identities from human identities
- aligns with least privilege principles
