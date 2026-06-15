# protectKernelDefaults sysctls

Template: [`../../templates/security/99-kubelet-enable-protect-kernel-sysctl.yaml`](../../templates/security/99-kubelet-enable-protect-kernel-sysctl.yaml)
Value flag: `machineConfigs.enableProtectKernelSysctl.enabled`

## What

Writes `/etc/sysctl.d/90-kubelet.conf` with the kernel sysctls
the kubelet expects when `protectKernelDefaults: true` is set:

```
vm.overcommit_memory=1
vm.panic_on_oom=0
kernel.panic=10
kernel.panic_on_oops=1
kernel.keys.root_maxkeys=1000000
kernel.keys.root_maxbytes=25000000
```

It runs at `sync-wave: "0"` so the sysctls land **before** the
KubeletConfig that turns on `protectKernelDefaults` — otherwise
the kubelet refuses to start. See
<https://access.redhat.com/solutions/5957791>.

## Why

This is the node-side half of the CIS
`kubelet-enable-protect-kernel-sysctl` control. With
`protectKernelDefaults` on, the kubelet will not silently change
kernel tunables; instead the values must already match, which
this file guarantees.

## Status

**Disabled.** As noted inline in `values.yaml`, this does not
work on Fedora CoreOS nor RHCOS, so both this flag and the paired
`kubeletConfigs.protectKernelDefaults` are off. Kept here so the
relationship/ordering is documented if it is ever revisited.

## Related

- [kubeletconfig/kubeletconfig-mcp.md](kubeletconfig/kubeletconfig-mcp.md)
  — the `protectKernelDefaults` kubelet setting this file backs.
