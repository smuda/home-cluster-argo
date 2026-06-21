# Chart conventions and adding an addon

## Chart roles (recap)

See [architecture.md](architecture.md) for the full picture. Briefly:

- **Root** (`_start/`) — selects layers per cluster.
- **Layer "start"** (`cluster-addons/_start/`, `okd/_start/`) — one
  `Application` template per component, gated by `<component>.use`.
- **Leaf** (`cluster-addons/<name>/`) — a thin umbrella chart wrapping
  an upstream chart, plus any local glue (quotas, network policies,
  config CRs).

## The umbrella-chart pattern

A leaf chart usually declares the upstream chart as a dependency under
the alias `upstream`:

```yaml
# cluster-addons/reloader/Chart.yaml
apiVersion: v2
name: reloader-install
version: 1.0.0
type: application
dependencies:
  # https://github.com/stakater/Reloader/releases
  - name: reloader
    version: 2.2.12
    alias: upstream
    repository: https://stakater.github.io/stakater-charts
```

Consequences:

- Upstream values are set under the **`upstream:`** key in the leaf's
  `values*.yaml`.
- `Chart.lock` is committed; only the fetched `*.tgz` files are
  **git-ignored** (see `.gitignore`). Argo CD's repo-server clones the
  lock and renders with `helm dependency build`, so a committed,
  in-sync lock keeps renders deterministic instead of re-resolving
  upstream on every sync. Run `make update-lock` (or `helm dependency
  build`) locally to materialise the `*.tgz`.
- Pin the upstream `version` explicitly and keep the upstream
  release-notes URL in a comment, as above. Dependabot
  (`.github/dependabot.yml`) proposes bumps; regenerate the lock with
  `make update-lock` when you bump. The `helm-lockfile` workflow does
  this automatically on PRs, and CI's `helm dependency build` fails a
  PR whose lock is out of sync with `Chart.yaml`.

## The value-file set

Every chart carries the same value-file *names* so the cluster-type
propagation (see [cluster-types.md](cluster-types.md)) works uniformly:

```
values.yaml               # defaults, applied everywhere
values-kind.yaml          # kind overrides
values-k8s.yaml           # vanilla k8s overrides
values-okd.yaml           # OKD overrides
values-ocp.yaml           # OCP overrides
values-docker-cache.yaml  # pull-through cache overlay (additive)
```

Not every chart needs every file, but if a chart can run on a cluster
type, it should have that type's value file (even if nearly empty).

## Recipe: add a new cluster addon

Say you want to add an addon `foo` that wraps an upstream chart.

1. **Create the leaf chart** `cluster-addons/foo/`:
   - `Chart.yaml` with the upstream dependency aliased `upstream`
     (see pattern above).
   - `values.yaml` plus `values-<type>.yaml` for each supported
     cluster type, and `values-docker-cache.yaml` if it pulls images.
   - Any local templates (e.g. `templates/quota.yaml`,
     network policies, config CRs).
   - Document values with [helm-docs] (a `README.md` generated from the
     chart). This repo's convention is helm-docs for chart docs.

2. **Register it in the layer chart** by adding
   `cluster-addons/_start/templates/foo.yaml`. Copy an existing
   template such as `reloader.yaml` and change:
   - the gate `{{ if .Values.foo.use }}`
   - `metadata.name` (e.g. `addon-foo`)
   - `destination.namespace`
   - `source.path: cluster-addons/foo/`
   - the `podSecurityLevel` reference in `managedNamespaceMetadata`
   - the `sync-wave` if it must run before/after others.

3. **Add the flag and security level** to
   `cluster-addons/_start/values.yaml`:

   ```yaml
   foo:
     use: true
     podSecurityLevel: restricted
   ```

   Override `use` per cluster type in the corresponding
   `cluster-addons/_start/values-<type>.yaml` if it should not run
   everywhere.

4. **Lint locally** before committing:

   ```shell
   helm dependency build cluster-addons/foo
   helm lint cluster-addons/foo
   ```

   CI (`.github/workflows/lint-test.yaml`) runs `helm dependency build`
   + `helm lint` over **every** `Chart.yaml` on pull requests.

5. **Test on kind** with `make start-kind` (it tracks your branch), and
   confirm the Application syncs green in the Argo CD UI.

## Conventions worth keeping

- **Namespaces** for addons are prefixed `addon-` (e.g.
  `addon-cert-manager`); the Application sets `CreateNamespace=true`.
- **`ServerSideApply=true`** is used for charts with large CRDs.
- **Finalizers** (`resources-finalizer.argocd.argoproj.io`) are set via
  `argo.common.finalizers` so deleting an Application cleans up its
  resources.
- **Image references** that need the pull-through cache go in
  `values-docker-cache.yaml`, never hard-coded in templates.
- **Pod Security**: pick the least-privilege `podSecurityLevel` that
  works; document any `privileged` escalation in the values file.

[helm-docs]: https://github.com/norwoodj/helm-docs
