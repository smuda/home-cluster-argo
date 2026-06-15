# Local development with kind

`make start-kind` builds a complete cluster on your machine and
installs the whole stack through Argo CD, tracking **your current git
branch**. This is the fastest way to test a change end-to-end.

## Quick start

```shell
make install-kind   # one-time: go install sigs.k8s.io/kind
make start-kind     # build + bootstrap everything
make stop-kind      # tear the cluster down
```

Required binaries (the script checks for them and aborts if missing):
`jq`, `kind`, `helm`, `kubectl`, `argocd`, plus Docker.

After it finishes, get into the Argo CD UI:

```shell
# the script sets the admin password to "password"
argocd login argocd.apps.127.0.0.1.nip.io --insecure --username admin --password password
# or port-forward and read the generated secret:
kubectl -n argocd get secret argocd-initial-admin-secret -o json \
  | jq -r '.data.password' | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

## What `hack/run-in-kind.sh` does, in order

The Makefile target just runs `./hack/run-in-kind.sh`. Key variables
at the top of the script: `KUBE_VERSION` (the kind node image),
`CLUSTER_NAME=home-cluster`, `KUBECONFIG=~/.kube/home-cluster-argo`,
`USE_DOCKER_CACHE=True`, `INGRESS=ingressNginx`.

1. **Verify binaries** exist (see list above).
2. **Delete** any existing `home-cluster` kind cluster.
3. **Detect the git branch** (`git rev-parse --abbrev-ref HEAD`). This
   becomes the Argo CD `targetRevision`, so the cluster tracks your
   branch, not `main`.
4. **Pre-pull images** listed in `hack/preload.txt` and
   `hack/preload-extras.txt` to the local Docker daemon (reduces Docker
   Hub rate-limit pain). See "Image preloading" below.
5. **Create the kind cluster** from `hack/kind.yaml`
   (`kindest/node:${KUBE_VERSION}`), wait for it to be reachable.
6. **Preload** the pulled images into the kind node's containerd
   (`ctr images import`), so pods start without re-pulling.
7. **Seed sealed-secrets** — if `hack/sealed-secrets-secret.yml`
   exists, create the `addon-sealed-secrets` namespace and apply the
   sealing key so previously sealed secrets decrypt.
8. **Install Argo CD** into the `argocd` namespace from
   `hack/argo-install/` (a Helm chart wrapping the upstream `argo-cd`
   chart), and wait for its Deployments.
9. **Install the root Application** by `helm upgrade -i start ./hack/start`
   with:
   - `-f start/values-kind.yaml`
   - `-f start/values-docker-cache.yaml` (because `USE_DOCKER_CACHE=True`)
   - `--set targetRevision=<your branch>`
   - `--set-string helmParameters.addons.helmParameters.ingressNginx.use=true`

   This creates the `root` Application, which points back at `_start/`
   in this repo and kicks off the whole app-of-apps tree.
10. **Wait on CRDs/Deployments** that the rest of the stack depends on,
    polling until ready: Prometheus `servicemonitors` CRD,
    cert-manager `certificates` CRD, the ingress controller, then the
    cert-manager Deployments and `cert-manager-approver-policy`.
11. **Recreate the lab issuer** — delete the `lab-issuer` certificate
    and `lab-cluster-issuer` so cert-manager regenerates the local CA
    cleanly.
12. **Re-install Argo CD** with TLS enabled, now that cert-manager and
    the `lab-cluster-issuer` ClusterIssuer exist (gives the Argo CD
    server a real cert and metrics).
13. **Configure and log in** the `argocd` CLI against the
    `argocd.apps.127.0.0.1.nip.io` host.

## Networking: how localhost reaches the cluster

`hack/kind.yaml` maps host ports to the ingress controller:

```yaml
extraPortMappings:
  - containerPort: 30080   # -> host 80
  - containerPort: 30443   # -> host 443
```

Combined with **`nip.io`** wildcard DNS (`*.apps.127.0.0.1.nip.io`
always resolves to `127.0.0.1`), any ingress host under that domain is
reachable from your browser with no `/etc/hosts` edits. The
kubeadm patches in `kind.yaml` also expose controller-manager,
scheduler, etcd, and kube-proxy metrics on `0.0.0.0` so Prometheus can
scrape them.

## TLS in the local cluster

cert-manager runs with a self-signed CA. The `lab-cluster-issuer`
`ClusterIssuer` signs certificates from that CA, and
`cert-manager-approver-policy` policies (see
`cluster-addons/cert-manager-approver-policy/templates/policies/`)
whitelist the local domains (`*.apps.127.0.0.1.nip.io`, etc.). Browser
trust warnings are expected unless you import the CA.

## Image preloading

To avoid Docker Hub rate limits, the script preloads images. The list
in `hack/preload.txt` is regenerated from a running cluster with:

```shell
make update-kind-preload   # dumps in-use, non-infra images to hack/preload.txt
```

`hack/preload-extras.txt` is a manual supplement. Both are pulled to
Docker then imported into the kind node before the workloads start.

## Tips

- The kubeconfig is written to `~/.kube/home-cluster-argo` (mode 600),
  separate from your default kubeconfig.
- To test a feature branch, just check it out before `make start-kind`;
  the cluster will track that branch automatically.
- `make update-lock` refreshes all `Chart.lock` files
  (`helm dep update`) after bumping a dependency version.
