# Machine config reference

This folder documents *why* each MachineConfig /
KubeletConfig in this chart exists and what it changes on the
node. It mirrors the layout of [`../templates/`](../templates):
every template has a matching `.md` here at the same relative
path.

| Template | Doc |
| --- | --- |
| `templates/system/99-kargs-psi.yaml` | [system/99-kargs-psi.md](system/99-kargs-psi.md) |
| `templates/system/99-timezone.yaml` | [system/99-timezone.md](system/99-timezone.md) |
| `templates/system/99-chrony.yaml` | [system/99-chrony.md](system/99-chrony.md) |
| `templates/system/80-extensions.yaml` | [system/80-extensions.md](system/80-extensions.md) |
| `templates/security/99-kubelet-enable-protect-kernel-sysctl.yaml` | [security/99-kubelet-enable-protect-kernel-sysctl.md](security/99-kubelet-enable-protect-kernel-sysctl.md) |
| `templates/security/kubeletconfig/kubeletconfig-mcp.yaml` | [security/kubeletconfig/kubeletconfig-mcp.md](security/kubeletconfig/kubeletconfig-mcp.md) |
| `templates/hooks/*.yaml` | [hooks/sync-hooks.md](hooks/sync-hooks.md) |

## Conventions

Each doc covers, briefly:

- **What** the config changes on the node.
- **Why** it is enabled (or disabled).
- **Value flag(s)** in `values.yaml` that gate it.
- **How to verify** it took effect.

Most configs are rendered once per entry in
`machineConfigPools` (`master`, `worker`) and carry the
`machineconfiguration.openshift.io/role: <pool>` label so the
Machine Config Operator rolls them out per pool. Applying a
MachineConfig **reboots** the targeted nodes one at a time; the
sync hooks (see [hooks/sync-hooks.md](hooks/sync-hooks.md)) pause
the pools while Argo CD syncs so reboots don't happen mid-sync.

When you add a template, add the matching doc here and a row to
the table above.
