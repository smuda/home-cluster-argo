# Architecture

Everything is installed through Argo CD using the **app-of-apps**
pattern: an `Application` whose job is to create more
`Application` resources. There is no imperative install step beyond
bootstrapping the very first Application (see
[local-kind.md](local-kind.md) for kind, or [openshift.md](openshift.md)
for OKD/OCP).

## The hierarchy

```
root Application                         (hack/start, or OpenShift GitOps)
└── _start/                              app-of-apps ROOT chart
    ├── addons-start  ───────────────►  cluster-addons/_start/
    │                                    ├── addon-cert-manager  ► cluster-addons/cert-manager/
    │                                    ├── addon-ingress-nginx ► cluster-addons/ingress-nginx/
    │                                    ├── addon-reloader      ► cluster-addons/reloader/
    │                                    └── ... one per addon
    ├── okd-start  ──────────────────►  okd/_start/             (only when okd.use=true)
    │                                    ├── openshift-gitops-operator
    │                                    ├── compliance-operator
    │                                    └── ... OpenShift operators
    ├── cluster-admins  ─────────────►  cluster-admins/
    └── openshift-gitops-operator   ►   okd/openshift-gitops-operator/ (OCP/OKD bootstrap)
```

Each box is an Argo CD `Application`. The leaf Applications point at
a Helm chart directory in this same repo (`repoURL` is always
`github.com/smuda/home-cluster-argo.git`).

## The three chart roles

1. **Root chart** — `_start/`. Decides *which layers* are active
   (`addons.use`, `okd.use`, `clusterAdmins.use`,
   `openshiftGitOpsOperator.use`). One per cluster.

2. **Layer "start" charts** — `cluster-addons/_start/`,
   `okd/_start/`. Each renders one `Application` per component, gated
   by a `<component>.use` flag in its `values.yaml`. These are the
   fan-out points.

3. **Leaf charts** — e.g. `cluster-addons/reloader/`,
   `cluster-addons/cert-manager/`. These are thin **umbrella charts**
   that wrap an upstream chart as a dependency (see [charts.md](charts.md)).

## How a leaf Application is rendered

Example: `cluster-addons/_start/templates/reloader.yaml`.

```yaml
{{ if .Values.reloader.use }}          # gate on the use flag
kind: Application
metadata:
  name: addon-reloader
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # ordering, see below
spec:
  destination:
    namespace: addon-reloader
  source:
    helm:
      valueFiles:                      # propagated cluster-type files
        {{- .Values.argo.common.valueFiles | toYaml | nindent 8 }}
    path: cluster-addons/reloader/     # the leaf chart
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated: { prune: true, selfHeal: true }
    managedNamespaceMetadata:          # Pod Security labels on the ns
      labels:
        pod-security.kubernetes.io/enforce: {{ .Values.reloader.podSecurityLevel }}
{{ end }}
```

Two things to notice, because they appear in almost every template:

- **`valueFiles` propagation** — `argo.common.valueFiles` is the
  cluster-type selector (e.g. `[values-kind.yaml]`). It is passed down
  to every leaf chart so the leaf can adapt to the cluster type. This
  is the central mechanism; see [cluster-types.md](cluster-types.md).
- **`managedNamespaceMetadata`** — Argo CD stamps Pod Security
  Standard labels onto each addon namespace, driven by the
  per-addon `podSecurityLevel` value
  (`restricted` / `baseline` / `privileged`).

## Parameters as values: `template.helmParameters`

The root and layer charts need to forward configuration *into* the
child Application's Helm `parameters` list. `_start/templates/_custom.tpl`
defines `template.helmParameters`, which recursively flattens a values
map/slice into Argo CD `- name: a.b.c` / `value:` parameter entries.

This is how, for example, `argo.common.target_revision` (the git
branch/tag to track) is threaded all the way down the tree without
hand-writing every parameter.

## Sync waves

Ordering between Applications uses the
`argocd.argoproj.io/sync-wave` annotation (lower runs first):

- wave `0` — addons that others depend on, and the OpenShift GitOps
  operator.
- wave `10` — the layer "start" Applications (`addons-start`,
  `okd-start`).

Within a cluster bootstrap, the practical dependency order
(cert-manager CRDs → cert-manager → issuers → ingress → the rest) is
enforced partly by sync waves and partly by the local bootstrap
script waiting on specific CRDs/Deployments (see
[local-kind.md](local-kind.md)).

## GitOps invariants

- **Do not `kubectl apply` cluster state by hand.** Change the chart
  or its values and let Argo CD reconcile. Most Applications run with
  `automated: { prune: true, selfHeal: true }`, so out-of-band changes
  are reverted.
- **`targetRevision` decides what the cluster tracks.** Production
  clusters track `main`. The local kind flow overrides it to the
  current git branch (`--set targetRevision=$(git branch)`), so you can
  test a feature branch end-to-end.
