# Cluster types and the value-file model

One repository serves several kinds of cluster. There are **no
per-cluster branches** — the difference between a kind cluster and an
OpenShift cluster is entirely expressed through which Helm value files
are active.

## The cluster types

| Type      | Value file        | What it is                                    |
| --------- | ----------------- | --------------------------------------------- |
| **kind**  | `values-kind.yaml`| Local dev cluster (the author calls this "b8s"). Run via `make start-kind`. |
| **k8s**   | `values-k8s.yaml` | Generic vanilla Kubernetes.                   |
| **OKD**   | `values-okd.yaml` | Community OpenShift distribution.             |
| **OCP**   | `values-ocp.yaml` | Red Hat OpenShift Container Platform.         |

Plus one **additive overlay** (not a cluster type on its own):

| Overlay        | Value file               | What it does                         |
| -------------- | ------------------------ | ------------------------------------ |
| docker-cache   | `values-docker-cache.yaml` | Rewrites image references to a pull-through cache to avoid Docker Hub rate limits. Layered *on top of* a cluster type via `additionalValueFiles`. |

> "b8s" is the author's verbal shorthand for a plain/basic Kubernetes
> cluster, which in practice is exercised with **kind** locally. In the
> repo it maps to `values-kind.yaml` (and `values-k8s.yaml` for a
> generic cluster). OKD and OCP are the two OpenShift flavours.

Every chart in the repo carries the **same set of value-file names**:
`values.yaml` (base/defaults) plus `values-<type>.yaml` overrides. Most
also have `values-docker-cache.yaml`.

## How a cluster type is selected and propagated

This is the key idea. It happens in two places:

### 1. The root chart picks the type

The root `_start/` chart has one value file per type whose only job is
to set `argo.common.valueFiles` — the list of value-file *names* that
every descendant chart should load.

`_start/values-kind.yaml`:

```yaml
argo:
  common:
    valueFiles:
      - values-kind.yaml   # <-- the selector
clusterAdmins:
  use: false
```

`_start/values-okd.yaml`:

```yaml
argo:
  common:
    valueFiles:
      - values-okd.yaml
okd:
  use: true                # turn on the okd/ layer
openshiftGitOpsOperator:
  use: true
```

### 2. Every Application forwards `valueFiles` to its child

Each `Application` template injects `argo.common.valueFiles` into the
child's `source.helm.valueFiles`:

```yaml
source:
  helm:
    valueFiles:
      {{- .Values.argo.common.valueFiles | toYaml | nindent 8 }}
      {{- with .Values.argo.common.additionalValueFiles }}
      {{- . | toYaml | nindent 8 }}      # docker-cache overlay, if any
      {{- end }}
```

So the selection made once at the root (`values-kind.yaml`) flows down
the entire tree. When the `reloader` leaf chart is rendered on a kind
cluster, Argo CD loads `cluster-addons/reloader/values.yaml` **and**
`cluster-addons/reloader/values-kind.yaml`. On OKD it loads
`values.yaml` + `values-okd.yaml` instead.

### Result

A leaf chart adapts to its cluster type purely by what is in its
`values-<type>.yaml`. Typical per-type differences:

- **Pod security / securityContext** — OpenShift assigns UIDs and runs
  SCCs itself, so OKD/OCP value files often strip `securityContext`
  and `runAsUser` that are required on kind/k8s.
- **Storage** — kind uses a CSI NFS / local provider; OpenShift uses
  its own storage classes.
- **Ingress / routes** — kind uses ingress-nginx with `nip.io`
  hostnames; OpenShift uses `Route` and the cluster ingress domain.
- **Enabled components** — e.g. `metricsServer.use=true` on kind (it
  ships none) but the addon set differs on OpenShift, which provides
  monitoring out of the box.

## Pod Security levels

Addon `_start` templates set Pod Security Standard labels on each
namespace from a per-component `podSecurityLevel` value
(`restricted`, `baseline`, or `privileged`) via Argo CD's
`managedNamespaceMetadata`. Choose the **most restrictive level the
workload tolerates**; only escalate (and document why) when an
upstream chart genuinely needs it — see the ODH operator note in
`okd/_start/values.yaml` for an example of a justified `privileged`.

## Practical rules when editing

- A change that must differ by cluster type goes in the relevant
  `values-<type>.yaml`, **not** in `values.yaml`.
- A change that is the same everywhere goes in `values.yaml`.
- When you add a new value-file *name*, add it to **every** chart that
  needs it and remember it only takes effect if the cluster type's root
  selector lists it.
- Keep the value-file set consistent across charts — the CI lints every
  `Chart.yaml`, and the bootstrap assumes the names line up.
