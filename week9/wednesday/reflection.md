# Week 9 Wednesday Reflection

## Question 1

**Explain the difference between a ConfigMap and a Secret in terms of what each is designed to hold and what protection each actually provides in the cluster. Why is base64 encoding not security?**

A ConfigMap is designed for non-sensitive configuration, while a Secret is intended for values that should not be exposed as ordinary application configuration. In the lab, `kk-payments-config` stored values such as `NODE_ENV`, `DB_HOST`, `DB_PORT`, `LOG_LEVEL`, `APP_PORT`, and `MAX_CONNECTIONS`. The `kk-payments-secrets` Secret instead contained `DB_PASSWORD`, `STRIPE_API_KEY`, and `JWT_SECRET`.

A Secret provides separation from the Deployment manifest and can be protected through Kubernetes access controls such as RBAC. However, the values stored in a standard Kubernetes Secret are base64 encoded, not automatically made confidential simply by that encoding. I demonstrated this when:

`kubectl get secret kk-payments-secrets -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode`

immediately returned `kijani-dev-password`. Base64 is only a reversible representation of data and requires no decryption key. Therefore, anyone who can read the encoded value can decode it. This is why the real Secret was created imperatively and was not committed to Git.

## Question 2

**In Phase 4, the LOG_LEVEL change did not take effect until after `kubectl rollout restart`. If kk-payments used a volume-mounted ConfigMap instead of environment variable injection, would the behaviour have been different? Explain what would have changed and what would have stayed the same.**

Yes. In Phase 4, `LOG_LEVEL` was injected using `envFrom`. After changing the ConfigMap from `warn` to `debug` and applying it, I ran:

`kubectl exec -it deployment/kk-payments -- env | grep LOG_LEVEL`

and the running container still returned `LOG_LEVEL=warn`. Only after `kubectl rollout restart deployment/kk-payments` completed did the new Pods report `LOG_LEVEL=debug`. Environment variables are populated when a container starts, so changing the ConfigMap does not modify the environment of an already-running process.

With a volume-mounted ConfigMap, Kubernetes would periodically refresh the mounted file contents, so the file containing `LOG_LEVEL` could change from `warn` to `debug` without recreating the Pod. However, this does not automatically mean the application's behaviour would change. The application would still need to reread or watch the configuration file. Therefore, the main difference is that a Pod restart would not necessarily be required to receive the updated file, while application support for reloading the configuration would still be required.

## Question 3

**Osei mentioned that the Deployment manifest references the ConfigMap and Secret by name, not by content. What does this mean for a scenario where you need to deploy the same Deployment manifest to a staging namespace that uses a different database host? How would you handle this with ConfigMaps without maintaining two copies of the Deployment manifest?**

The Deployment now references `kk-payments-config` through `envFrom` instead of containing values such as `DB_HOST` directly. This means the same Deployment definition can be used in different environments as long as each environment provides the expected ConfigMap.

For example, the production namespace could contain a `kk-payments-config` ConfigMap where `DB_HOST=postgres-prod.kijani.internal`, while the staging namespace could contain its own ConfigMap with the same name and keys but with a staging database hostname. Because ConfigMaps are namespace-scoped, the Deployment in each namespace resolves `kk-payments-config` within that namespace.

The Deployment manifest therefore does not need to know the actual database hostname and does not need separate production and staging copies. Environment-specific configuration is handled through the ConfigMap associated with each namespace, while the Deployment continues referencing the same ConfigMap name.

## Question 4

**You created the Secret imperatively and did not commit the manifest. Three months from now, a teammate needs to recreate the cluster from scratch using only the git repository. What will they find for the ConfigMap? What will they find for the Secret? What does this tell you about the operational dependency that Secrets create?**

The teammate will find `k8s/kk-payments-configmap.yaml` containing all six non-sensitive configuration values because that manifest was deliberately committed to Git. They can recreate it using `kubectl apply`.

For the Secret, they will only find `k8s/kk-payments-secrets.yaml.example`, which documents the required keys such as `DB_PASSWORD`, `STRIPE_API_KEY`, and `JWT_SECRET` without containing their real values. They will not be able to reconstruct `kk-payments-secrets` from the repository alone because the actual Secret was created imperatively and intentionally kept out of Git.

This creates an important operational dependency: the real secret values must exist somewhere outside the application repository and there must be a documented process for restoring them. In a production environment this would normally involve a dedicated secrets manager, secure deployment pipeline, or another protected source of credentials. Git can therefore reconstruct the non-sensitive configuration, but Git alone cannot completely reconstruct the application's runtime environment when sensitive configuration has intentionally been excluded from the repository.
