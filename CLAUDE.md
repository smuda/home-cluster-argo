# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Read the docs first

Before making changes, read [`docs/`](docs/README.md). It explains the
architecture and the conventions that are easy to get wrong here:

- [docs/README.md](docs/README.md) — overview and top-level layout.
- [docs/architecture.md](docs/architecture.md) — the app-of-apps
  hierarchy, sync waves, `template.helmParameters`.
- [docs/cluster-types.md](docs/cluster-types.md) — the multi-cluster
  model and the value-file propagation mechanism. **Read this before
  editing any values.**
- [docs/local-kind.md](docs/local-kind.md) — how `make start-kind`
  bootstraps a local cluster.
- [docs/charts.md](docs/charts.md) — chart conventions and the recipe
  for adding an addon.
- [docs/openshift.md](docs/openshift.md) — OKD/OCP specifics.

Keep the docs up to date when you change how things work.

## What this repo is

A GitOps repository. Argo CD installs everything via the app-of-apps
pattern, starting from `_start/`. The **same** repo drives multiple
cluster types — kind (local, the author's "b8s"), vanilla k8s, OKD,
and OCP — selected by Helm value files, not branches.

## The mental model (don't skip this)

1. **app-of-apps** — `_start/` (root) → layer `_start` charts
   (`cluster-addons/_start/`, `okd/_start/`) → leaf umbrella charts.
   Each box is an Argo CD `Application`.
2. **Cluster type = value-file selection.** The root sets
   `argo.common.valueFiles` (e.g. `[values-kind.yaml]`); every
   Application forwards it to its child, so each chart loads
   `values.yaml` + `values-<type>.yaml`. Per-type differences live in
   `values-<type>.yaml`, never in templates.
3. **Leaf charts are thin umbrellas** wrapping an upstream chart under
   the alias `upstream`. Upstream values go under the `upstream:` key.

## Working rules

- **GitOps, not kubectl.** Change charts/values and let Argo CD
  reconcile. Most Applications run `prune: true, selfHeal: true`, so
  manual cluster edits get reverted. Don't `kubectl apply` to "fix"
  state.
- **Per-cluster-type change** → edit that `values-<type>.yaml`.
  **Universal change** → edit `values.yaml`. See
  [docs/cluster-types.md](docs/cluster-types.md).
- **Adding an addon** → follow the recipe in
  [docs/charts.md](docs/charts.md): leaf chart + a template in the layer
  `_start/` + a `use`/`podSecurityLevel` entry in the layer
  `values.yaml`.
- **Pod Security**: pick the least-privilege `podSecurityLevel` that
  works; document any `privileged` escalation in the values file.
- **OpenShift**: OKD/OCP manage SCC and UIDs themselves — their value
  files often strip `securityContext`. See
  [docs/openshift.md](docs/openshift.md).
- **Dependencies**: `Chart.lock` is committed; fetched `*.tgz` stay
  git-ignored. Argo CD renders from the committed lock, so an in-sync
  lock keeps renders deterministic instead of re-resolving upstream on
  every sync. Pin the upstream `version` in `Chart.yaml` with a
  release-notes comment, and regenerate the lock (`make update-lock`)
  in the same change. CI's `helm dependency build` fails a PR whose
  lock is out of sync; the `helm-lockfile` workflow regenerates locks
  automatically on PRs that touch a `Chart.yaml`.

## Validate before committing

```shell
helm dependency build <chart-dir>     # materialise deps
helm lint <chart-dir>                 # CI lints every Chart.yaml on PRs
helm template -f <chart-dir>/values-<type>.yaml <chart-dir>   # inspect render
make start-kind                       # full end-to-end test on kind (tracks your branch)
```

CI (`.github/workflows/lint-test.yaml`) runs `helm dependency build` +
`helm lint` over every chart. Per the global testing policy, make sure
the kind bootstrap still comes up green before committing changes that
touch the bootstrap chain.

## Conventions

- Addon namespaces are prefixed `addon-`; Applications set
  `CreateNamespace=true`.
- Chart docs use [helm-docs](https://github.com/norwoodj/helm-docs).
- Commits use Conventional Commits; keep the subject under 72 chars and
  do not add `Co-authored-by` lines.
- Markdown wraps at 72 characters.
