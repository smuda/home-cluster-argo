# Documentation

This directory documents how `home-cluster-argo` is structured and
how to operate it. Start here, then dive into the topic you need.

## What this repository is

A GitOps repository that bootstraps and manages the author's home
Kubernetes clusters with [Argo CD]. A single "root" Argo CD
`Application` points at this repo; everything else is installed
through nested `Application` resources (the "app-of-apps" pattern).

The same repository drives several different cluster *types* (kind,
vanilla Kubernetes, OKD, OpenShift/OCP). Per-type behaviour is
selected through a chain of Helm value files rather than separate
branches or directories.

## Reading order

1. [architecture.md](architecture.md) — the app-of-apps hierarchy,
   how a change flows from the root Application down to a workload,
   and Argo CD sync waves.
2. [cluster-types.md](cluster-types.md) — the multi-cluster model
   (kind, k8s, OKD, OCP), and the value-file propagation mechanism
   that makes one repo serve all of them.
3. [local-kind.md](local-kind.md) — how `make start-kind` builds a
   full cluster locally, step by step.
4. [charts.md](charts.md) — chart conventions and a recipe for
   adding a new addon.
5. [openshift.md](openshift.md) — OKD/OCP specifics (the OpenShift
   GitOps operator, SCC, Pod Security, machine configs).

## Top-level layout

| Path              | Purpose                                              |
| ----------------- | ---------------------------------------------------- |
| `_start/`         | Root app-of-apps chart. Fans out to the layers.     |
| `cluster-addons/` | Infrastructure addons (cert-manager, ingress, etc). |
| `okd/`            | OpenShift/OKD-only operators and configuration.     |
| `apps/`           | End-user application workloads.                      |
| `cluster-admins/` | Cluster-admin RBAC / group bindings.                |
| `hack/`           | Local bootstrap tooling (kind, argo-install).       |
| `demos/`          | Standalone demos, not part of the bootstrap chain.  |
| `docs/`           | This documentation.                                 |

[Argo CD]: https://argo-cd.readthedocs.io/
