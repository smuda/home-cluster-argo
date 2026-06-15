# Chrony / NTP configuration

Template: [`../../templates/system/99-chrony.yaml`](../../templates/system/99-chrony.yaml)
Value flag: `system.chrony.enabled`

## What

Replaces `/etc/chrony.conf` on every node with the contents of
[`../../files/system/chrony.conf`](../../files/system/chrony.conf),
base64-embedded into the ignition config. This points the node's
NTP client at the desired time sources.

## Why

Accurate clocks are a hard requirement for a Kubernetes cluster:
TLS validation, certificate rotation, etcd, and log correlation
all break under clock skew. Owning `chrony.conf` lets us pin the
cluster to specific (e.g. local/LAN) NTP servers instead of the
defaults.

## Editing

The file content lives in `files/system/chrony.conf`, **not** in
the template — edit that file and let the template re-embed it.
See the chart README's notes on `butane` for the related system
configs.

## Verify

```shell
oc debug node/<name> -- chroot /host chronyc sources
```
