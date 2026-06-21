# Log aggregation on kind / k8s

How container logs are collected and stored on the non-OpenShift
cluster types (`kind` and vanilla `k8s`). For OpenShift (OKD/OCP) see
[logaggregation-okd.md](logaggregation-okd.md).

## The two pieces

Log aggregation is split into a store and a collector, each its own
addon so they can be toggled independently:

| Piece | Addon | Upstream chart | Runs as |
| ----- | ----- | -------------- | ------- |
| Store | `cluster-addons/victoria-logs/` | `victoria-logs-single` | StatefulSet + PVC |
| Collector | `cluster-addons/victoria-logs-collector/` | `victoria-logs-collector` | vlagent DaemonSet |

Both are wired into the layer chart with their own `use` flags in
`cluster-addons/_start/values.yaml`:

```yaml
victoriaLogs:
  use: true
  podSecurityLevel: restricted
victoriaLogsCollector:
  use: true
  podSecurityLevel: privileged
```

## How it flows

```
  ┌─────────────────────────┐         ┌──────────────────────────┐
  │ node: /var/log/pods/**   │         │  VictoriaLogs (store)     │
  │                          │         │  StatefulSet + PVC        │
  │  vlagent DaemonSet  ─────┼────────▶│  Service :9428            │
  │  (one pod per node)      │ /insert │  built-in VMUI            │
  └─────────────────────────┘ /native └──────────────────────────┘
        addon-victoria-logs-collector        addon-victoria-logs
```

1. The vlagent DaemonSet runs one pod per node and tails the
   container logs under the node's `/var/log` (mounted read-only),
   enriching each line with `kubernetes.*` stream fields (namespace,
   pod, container).
2. It ships them to the store's Service over the native ingestion
   endpoint:

   ```
   http://victoria-logs-upstream-server.addon-victoria-logs.svc.cluster.local:9428/insert/native
   ```

   The target is set in `cluster-addons/victoria-logs-collector/values.yaml`
   under `upstream.remoteWrite[].url`.
3. VictoriaLogs stores the logs on its PersistentVolume (10Gi,
   one-month retention by default; 2Gi on kind) and serves both the
   ingestion API and the query UI on port `9428`.

## Storage and pod security

The store runs under PodSecurity `restricted`. The upstream chart omits
`seccompProfile`, which `restricted` requires, so the store value file
sets it explicitly — without it the pod is refused admission and the
`WaitForFirstConsumer` PVC hangs `Pending` with no consumer:

```yaml
# cluster-addons/victoria-logs/values.yaml
upstream:
  server:
    podSecurityContext:
      seccompProfile:
        type: RuntimeDefault
```

The collector needs host-path access to the node log directories, which
the `restricted`/`baseline` volume allowlist forbids, so its namespace
runs `privileged`.

## Querying

The store exposes the built-in VMUI and the LogsQL HTTP API on
`9428`, reachable through the addon's ingress
(`logs.apps.127.0.0.1.nip.io` on kind) or a port-forward:

```shell
kubectl -n addon-victoria-logs \
  port-forward svc/victoria-logs-upstream-server 9428:9428

# total hits in the last 24h
curl -s 'http://localhost:9428/select/logsql/hits?query=*&step=24h'

# last few application log lines
curl -s 'http://localhost:9428/select/logsql/query?query=*&limit=5'
```

## Exposure note

On kind/k8s the ingress is unauthenticated, which is acceptable for a
local cluster on `127.0.0.1`. VictoriaLogs has no built-in auth, so
any real (non-local) exposure must be fronted with an auth layer. On
OpenShift that is solved with an OAuth proxy sidecar — see
[logaggregation-okd.md](logaggregation-okd.md).
