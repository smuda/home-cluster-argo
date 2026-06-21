# Log aggregation on OpenShift (OKD / OCP)

How container logs are collected, stored, and exposed on the OpenShift
cluster types. OKD and OCP work identically — everything below applies
to both; the only differences are noted inline (operator catalog and the
oauth-proxy image registry), and they are expressed in `values-okd.yaml`
vs `values-ocp.yaml`. For the non-OpenShift path see
[logaggregation-k8s.md](logaggregation-k8s.md).

## Same store, different collector and exposure

The log store is the same `cluster-addons/victoria-logs/` chart used
everywhere — there is no separate OpenShift chart. The cluster-type
value files adapt it: OpenShift's SCC assigns the pod UID/fsGroup, the
unauthenticated ingress is dropped, and an OAuth proxy is added. See
[cluster-types.md](cluster-types.md) for the value-file model.

What differs from kind/k8s:

| Concern | kind / k8s | OpenShift (OKD/OCP) |
| ------- | ---------- | ------------------- |
| Collector | `victoria-logs-collector` (vlagent DaemonSet) | OpenShift Logging operator → Vector |
| Ingestion API | `/insert/native` | `/insert/elasticsearch/_bulk` |
| Exposure | plain ingress (local only) | reencrypt Route behind oauth-proxy |
| Auth | none (localhost) | cluster OAuth, cluster admins only |

The vlagent collector is therefore disabled on OpenShift
(`victoriaLogsCollector.use: false` in
`cluster-addons/_start/values-okd.yaml` / `-ocp.yaml`).

## How it flows

```
  ┌───────────────────────────┐      ┌──────────────────────────────┐
  │ OpenShift Logging operator │      │  VictoriaLogs (store)         │
  │  Vector collector (DS)     │      │  StatefulSet + PVC            │
  │   ↑ ClusterLogForwarder    ├─────▶│  Service :9428 (in-cluster)  │
  └───────────────────────────┘ /insert└─────────────┬────────────────┘
        openshift-logging      /elasticsearch         │ localhost:9428
                                                      ▼
   user ──HTTPS──▶ Route(reencrypt) ──▶ oauth-proxy :8443  (same pod)
                    (cluster OAuth,        ↑ TLS via service-ca
                     cluster admins)
```

### Collection — the OpenShift Logging operator

Two addons in the `okd/` layer, both gated by `openshiftLogging.use`:

- `okd/openshift-logging-operator/` — an OLM `OperatorGroup` +
  `Subscription` for the Cluster Logging operator (channel `stable-6.2`).
  This operator's collector is Vector. (OCP pulls the same package from
  `redhat-operators`; on OKD it comes from the configured catalog
  source.)
- `okd/openshift-logging-config/` — the collector identity
  (`ServiceAccount` + the `collect-application/infrastructure/audit-logs`
  ClusterRoleBindings) and a `ClusterLogForwarder`
  (`observability.openshift.io/v1`). The operator renders that CR into a
  Vector DaemonSet.

The `ClusterLogForwarder` ships application, infrastructure, and audit
logs to the store's Elasticsearch bulk endpoint, with URL query
params mapping OpenShift fields onto VictoriaLogs stream/time/message
fields:

```
http://victoria-logs-upstream-server.addon-victoria-logs.svc.cluster.local:9428/insert/elasticsearch/_bulk?...
```

The endpoint is set in `okd/openshift-logging-config/values.yaml`
(`victoriaLogs.endpoint`). Ingestion uses the in-cluster `:9428`
Service directly — it is not exposed outside the cluster. Reference:
the [VictoriaMetrics OpenShift guide][vm-okd].

### Exposure — oauth-proxy sidecar

VictoriaLogs has no built-in authentication, so on OpenShift it must not
be reachable unauthenticated. It is fronted by an oauth-proxy sidecar in
the store pod — the same model `openshift-gitops` uses — configured
entirely in `values-okd.yaml` / `values-ocp.yaml`:

1. The store ServiceAccount carries an `oauth-redirectreference`
   annotation, so it acts as the OAuth client for the cluster's built-in
   OAuth server.
2. The Service is annotated with
   `service.beta.openshift.io/serving-cert-secret-name`, so service-ca
   issues the TLS cert the sidecar serves on `:8443`.
3. The oauth-proxy sidecar proxies authenticated requests to the
   VictoriaLogs container on `localhost:9428`. The image is the
   community `origin-oauth-proxy` on OKD; on OCP it is the cluster's
   release-payload oauth-proxy (the integrated registry may be removed
   and `registry.redhat.io` had no matching tag), referenced by digest —
   see `values-ocp.yaml` for how to refresh it after an upgrade.
4. A reencrypt Route is the only external entrypoint, targeting the
   sidecar's `:8443` port. The plain `:9428` Service stays in-cluster.
5. A `system:auth-delegator` ClusterRoleBinding lets the proxy run
   the TokenReview / SubjectAccessReview it uses to authorize callers.

#### Who is allowed in

Authorization is a SubjectAccessReview passed to oauth-proxy:

```
-openshift-sar={"namespace":"openshift-config","resource":"secrets","verb":"get"}
```

Reading secrets in `openshift-config` is a cluster-admin-only
permission, so only cluster admins can reach the UI/API. To grant a
different group, change this SAR to a permission that group holds (or
bind that group to a role and probe it here).

> Cookie signing: oauth-proxy requires a cookie-secret (the session
> signing key), mounted via `-cookie-secret-file`. It is not committed to
> git — leaking it allows session forgery (auth bypass). Provision it
> once out-of-band as Secret `victoria-logs-oauth-cookie` (key
> `session_secret`) in `addon-victoria-logs`, ideally a SealedSecret, e.g.:
>
> ```shell
> oc -n addon-victoria-logs create secret generic \
>   victoria-logs-oauth-cookie \
>   --from-literal=session_secret="$(openssl rand -base64 32)"
> ```

## Enabling / disabling

- Store: `victoriaLogs.use` (on for all types).
- OpenShift Logging operator + forwarder: `openshiftLogging.use` in
  `okd/_start/values.yaml`.
- The store namespace runs PodSecurity `restricted`; the operator's
  Vector collector namespace (`openshift-logging`) runs `privileged`
  because the collector mounts node log paths.

## Verifying

```shell
# Forwarder accepted and collector running
oc -n openshift-logging get clusterlogforwarder logging
oc -n openshift-logging get pods         # vector collector DaemonSet

# Route is admin-gated; log in via the cluster OAuth login page
oc -n addon-victoria-logs get route victoria-logs

# In-cluster query (bypasses oauth, for debugging)
oc -n addon-victoria-logs exec sts/victoria-logs-upstream-server -- \
  wget -qO- 'http://localhost:9428/select/logsql/hits?query=*&step=1h'
```

[vm-okd]: https://docs.victoriametrics.com/guides/collecting-openshift-logs-with-victoria-logs/
