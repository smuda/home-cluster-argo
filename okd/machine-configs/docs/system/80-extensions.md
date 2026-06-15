# RHCOS/FCOS extensions

Template: [`../../templates/system/80-extensions.yaml`](../../templates/system/80-extensions.yaml)
Value flag: `system.extensions.usbGuard`

## What

Enables optional OS extensions (layered RPMs the Machine Config
Operator installs onto the immutable OS image). Currently the
only wired-up extension is `usbguard`, gated by
`system.extensions.usbGuard`.

## Why

Extensions let you add a small set of supported packages
(usbguard, kerberos, sandboxed-containers, …) without building a
custom OS image. `usbguard` is a CIS-hardening item that
whitelists permitted USB devices.

## Status

`usbGuard` is **disabled** by default: the `usbguard` extension
package does not exist for Fedora CoreOS (the OKD node OS), so
enabling it on OKD fails. It is left as a flag for OCP/RHCOS,
where the extension is available.

## Verify

```shell
oc debug node/<name> -- chroot /host rpm -q usbguard
```
