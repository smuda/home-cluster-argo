# KubeletConfig per machine config pool

Template: [`../../../templates/security/kubeletconfig/kubeletconfig-mcp.yaml`](../../../templates/security/kubeletconfig/kubeletconfig-mcp.yaml)
Value root: `kubeletConfigs.*`

## What

Emits one `KubeletConfig` per machine config pool, selected by
the `pools.operator.machineconfiguration.openshift.io/<pool>`
label. Each sub-setting is independently gated by
`kubeletConfigs.<name>.enabled` **and** membership of the pool in
that setting's `targetMachineConfigPools` list.

| Setting                 | Value flag                       | Effect                                                                             |
|-------------------------|----------------------------------|------------------------------------------------------------------------------------|
| Auto-sized reservations | `autosizeReserved`               | `autoSizingReserved: true` — kubelet sizes system/kube reserved from node capacity |
| Event QPS               | `eventRecordQPS`                 | `eventRecordQPS: 5` — cap kubelet event creation rate (CIS)                        |
| Eviction timing         | `evictionConfig`                 | `evictionPressureTransitionPeriod: 0s`, `evictionMaxPodGracePeriod: 120`           |
| Soft eviction           | `evictionSoft`                   | soft thresholds + grace periods for imagefs/memory/nodefs                          |
| Hard eviction           | `evictionHard`                   | hard thresholds for imagefs/memory/nodefs (CIS)                                    |
| iptables chains         | `makeIPTablesUtilChains`         | `makeIPTablesUtilChains: true` (CIS)                                               |
| Protect kernel defaults | `protectKernelDefaults`          | `protectKernelDefaults: true` (CIS) — see note below                               |
| Streaming timeout       | `streamingConnectionIdleTimeout` | `5m0s` idle timeout for exec/attach (CIS)                                          |
| TLS cipher suites       | `tlsCipherSuites`                | restricts kubelet TLS to a strong cipher list (CIS)                                |

## Why

This is where most of the CIS kubelet hardening and the node
resource-management policy live, expressed as one declarative
KubeletConfig per pool instead of raw kubelet flags. Splitting
each control behind its own flag + pool list lets master and
worker diverge (e.g. apply a control only to workers).

## Notes

- `protectKernelDefaults` is **off** — it breaks on FCOS/RHCOS.
  When on, it must be paired with the sysctl file in
  [../99-kubelet-enable-protect-kernel-sysctl.md](../99-kubelet-enable-protect-kernel-sysctl.md),
  which must apply first.
- Bad KubeletConfigs can wedge a node mid-update; see the chart
  README for `journalctl -b -u kubelet` and the
  `/run/machine-config-daemon-force` recovery trick.

## Verify

```shell
oc get kubeletconfig
oc debug node/<name> -- chroot /host \
  cat /etc/kubernetes/kubelet.conf
```
