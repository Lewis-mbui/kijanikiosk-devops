# KijaniKiosk Kubernetes Deployment

All manifests in this directory target the `kijani-project` namespace.

## Required Secret

The `kk-payments-secrets` Secret is intentionally not committed with real values.

Expected keys:

- `DB_PASSWORD`
- `STRIPE_API_KEY`
- `JWT_SECRET`

Before applying the kk-payments Deployment in a fresh cluster, recreate this Secret securely using values obtained from the team.

Example structure is documented in:

`kk-payments-secrets.yaml.example`
