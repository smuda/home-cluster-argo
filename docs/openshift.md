# OpenShift (OKD and OCP) specifics

OKD (community) and OCP (Red Hat) are the two OpenShift flavours this
repo supports. They share the `okd/` layer and differ only by value
file (`values-okd.yaml` vs `values-ocp.yaml`). Both set `okd.use=true`
and `openshiftGitOpsOperator.use=true` in the root chart.

## Bootstrap differs from kind

On kind, `hack/run-in-kind.sh` installs the upstream Argo CD Helm chart
directly. On OpenShift, Argo CD comes from the **OpenShift GitOps
Operator** instead:

- `_start/templates/openshift/openshift-gitops-operator.yaml` creates an
  Application pointing at `okd/openshift-gitops-operator/` (operator
  `Subscription` + `OperatorGroup`).
- `okd/openshift-gitops/` then configures the resulting Argo CD
  instance (the `ArgoCD` CR, RBAC cluster roles/bindings, rollout
  manager).
- The root Application itself is applied into the OpenShift GitOps
  namespace to start the app-of-apps chain.

## The `okd/` layer

`okd/_start/` fans out to OpenShift-only components, each gated by a
`use` flag in `okd/_start/values.yaml`:

| Component                          | Purpose                                  |
| ---------------------------------- | ---------------------------------------- |
| `openshift-gitops-operator`        | Installs Argo CD via OLM.                |
| `operator-catalog-sources`         | Extra OLM catalog sources.               |
| `compliance-operator` (+ config)   | CIS/compliance scanning.                 |
| `csr-auto-approver`                | Auto-approves kubelet serving CSRs.      |
| `keda` (+ config)                  | Event-driven autoscaling.                |
| `machine-configs` / `machine-pre-configs` | Node-level `MachineConfig`s.      |
| `open-data-hub-operator`           | Open Data Hub / AI platform operator.    |
| `openshift-vertical-pod-autoscaler`| VPA operator.                            |
| `patch-operator`                   | Applies post-install patches to cluster objects. |
| `garbage-collector`                | Cleans up orphaned resources.            |

Components are configured through OLM `Subscription`/`OperatorGroup`
resources and operator-specific CRs, rather than plain Deployments.

## SCC and Pod Security

OpenShift runs its own **Security Context Constraints (SCC)** and
assigns container UIDs from a namespace range. Consequences for charts:

- `values-okd.yaml` / `values-ocp.yaml` frequently **remove**
  `securityContext`, `runAsUser`, and `fsGroup` that are mandatory on
  kind/k8s, letting OpenShift inject them. (See the README note: "OKD
  manages a lot of that stuff itself.")
- Pod Security Standard levels still apply via
  `managedNamespaceMetadata`. When an upstream operator can't meet
  `restricted` (e.g. it omits a `seccompProfile`), the namespace is set
  `privileged` **and** the SCC label-sync is disabled so OpenShift
  doesn't overwrite the level. The Open Data Hub operator in
  `okd/_start/values.yaml` is the documented example of this.

## Monitoring

OpenShift ships cluster monitoring (Prometheus/Thanos), so the
Grafana addon on OKD points its datasource at the in-cluster **Thanos
querier** through an OAuth proxy, rather than running a standalone
Prometheus (see `cluster-addons/grafana-operator/templates/okd/`). This
is a good example of a chart behaving very differently per cluster
type, driven entirely by `values-okd.yaml`.

## Local note

There is no fully local OpenShift flow in this repo; kind is the local
target. OKD/OCP value files are exercised on real clusters. When
changing OpenShift-only resources, lint with `helm lint` and review the
rendered output with `helm template -f <chart>/values-okd.yaml`.
