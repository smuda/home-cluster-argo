# Node timezone

Template: [`../../templates/system/99-timezone.yaml`](../../templates/system/99-timezone.yaml)
Value flag: `system.timezone.enabled`

## What

Installs a oneshot systemd unit (`custom-timezone.service`) that
runs `timedatectl set-timezone Europe/Stockholm` on boot, setting
the node's local timezone.

## Why

Keeps node-level logs and `journalctl` timestamps in the
operator's local timezone, which makes correlating host logs with
real-world events easier. Note this does **not** change container
timezones — pods still see UTC unless they set their own `TZ`.

The target zone (`Europe/Stockholm`) is hard-coded in the unit;
change it in the template if the cluster moves.

## Verify

```shell
oc debug node/<name> -- chroot /host timedatectl
```
