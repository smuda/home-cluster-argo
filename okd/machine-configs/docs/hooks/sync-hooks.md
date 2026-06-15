# MCP pause / resume sync hooks

Templates:
[`../../templates/hooks/pre-sync-job.yaml`](../../templates/hooks/pre-sync-job.yaml),
[`../../templates/hooks/post-sync-job.yaml`](../../templates/hooks/post-sync-job.yaml)

## What

Two Argo CD hook Jobs that bracket every sync of this chart:

- **PreSync** (`mcp-worker-pause-job`): for each pool, waits for
  it to be `updated`, then patches `spec.paused: true`.
- **PostSync** (`mcp-worker-resume-job`): patches
  `spec.paused: false` to let queued updates roll out.

Both run as the `mcp-sync-job-sa` service account and use the
`ose-cli` image to call `oc`.

## Why

Changing a MachineConfig triggers a rolling reboot of the pool.
If Argo CD is applying several MachineConfigs in one sync, an
unpaused pool would start rebooting nodes after the first change
and reboot again for each subsequent one. Pausing the pools for
the duration of the sync batches all changes into a **single**
rollout once the pool is resumed — fewer reboots, no churn
mid-sync.

The PreSync job also fails fast (`oc wait ... --for
condition=updated`) if a pool is already mid-update, so a sync
won't pile onto an in-flight rollout.

## Verify

```shell
oc get machineconfigpool        # PAUSED column during a sync
```

The hooks self-delete on success
(`hook-delete-policy: HookSucceeded`).
