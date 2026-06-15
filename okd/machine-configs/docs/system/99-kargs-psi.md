# Pressure Stall Information (PSI)

Template: [`../../templates/system/99-kargs-psi.yaml`](../../templates/system/99-kargs-psi.yaml)
Value flag: `system.psi.enabled`

## What

Adds the `psi=1` kernel argument to every machine config pool.
This turns on the kernel's Pressure Stall Information feature
(`CONFIG_PSI`), which tracks how much time tasks spend stalled
waiting on CPU, memory, and IO.

When enabled the kernel exposes:

- `/proc/pressure/cpu`
- `/proc/pressure/memory`
- `/proc/pressure/io`

and the equivalent `*.pressure` files inside every cgroup v2
slice, so pressure can be attributed per workload.

Because this is a `kernelArguments` change, the Machine Config
Operator reboots each node in the pool to apply it.

## Why

PSI is the canonical signal for "is this node actually
saturated?" — far more useful than load average or raw
utilisation, because it measures *lost time* due to resource
contention. It feeds node-pressure eviction, autoscaling
decisions, and saturation dashboards/alerts.

On Fedora CoreOS / RHCOS the kernel is built with PSI support but
it is **off by default** (`psi=0`); the `psi=1` karg is what
actually enables it.

## Metrics

With PSI on, `node_exporter` publishes the following series
(scraped by the cluster monitoring stack). `*_waiting_*` =
*some* tasks stalled; `*_stalled_*` = *all* tasks stalled (full
stall). CPU has no "full" variant by design.

| Metric                                       | Meaning                          |
|----------------------------------------------|----------------------------------|
| `node_pressure_cpu_waiting_seconds_total`    | Time some tasks waited on CPU    |
| `node_pressure_memory_waiting_seconds_total` | Time some tasks waited on memory |
| `node_pressure_memory_stalled_seconds_total` | Time all work stalled on memory  |
| `node_pressure_io_waiting_seconds_total`     | Time some tasks waited on IO     |
| `node_pressure_io_stalled_seconds_total`     | Time all work stalled on IO      |

These are counters in seconds. Take `rate(...[5m])` to get the
fraction of wall-clock time spent under pressure (0–1 per core
basis); a sustained memory `stalled` rate near 1 means the node
is thrashing.

## Verify

On a node (`oc debug node/<name>` → `chroot /host`):

```shell
cat /proc/cmdline        # should contain psi=1
cat /proc/pressure/cpu   # should print avg10/avg60/avg300 + total
```

Or from Prometheus:

```promql
rate(node_pressure_memory_waiting_seconds_total[5m])
```
