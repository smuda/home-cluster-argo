# ArgoCD with helm pre-install

With a pre-install helm hook, for example with flyway,
the job is run before anything else is installed.
That might be a problem when that job requires a secret
which is part of the installation, since the secret
is installed after the job is triggered, making the
pod wait for the secret and then failing.

The solution is to mark the secret as part of the helm
job. Strangely enough, this works even when
using multisource application where the
secret resides in a raw directory.

```yaml
apiVersion: v1
kind: Secret
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: helm-pre-install-hook:/Secret:addon-helm-pre-install-hook/update-db-secret
    helm.sh/hook: pre-install
    helm.sh/hook-delete-policy: hook-succeeded
    helm.sh/hook-weight: "-5"
stringData:
  secret.json: |
    { "foo": "bar" }
```
