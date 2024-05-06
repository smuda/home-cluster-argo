# Policies

## Violations

* [P2001: Containers must not run as root](#p2001-containers-must-not-run-as-root)
* [P2002: Containers must define resource constraints](#p2002-containers-must-define-resource-constraints)

## Warnings

* [P2003: Containers should not have a writable root filesystem](#p2003-containers-should-not-have-a-writable-root-filesystem)

## P2001: Containers must not run as root

**Severity:** Violation

**Resources:** core/Pod apps/DaemonSet apps/Deployment apps/StatefulSet

Running containers as root can allow too much rights on the node.
As such, they are not allowed.

### Rego

```rego
package container_warn_run_as_non_root

import data.lib.core
import data.lib.pods

policyID := "P2001"

violation[msg] {
     some container
     pods.containers[container]

    not container.securityContext.runAsNonRoot

    msg := core.format_with_id(
        sprintf("%s/%s/%s: Containers must not run as root", [core.kind, core.name, container.name]),
        policyID,
    )
}
```

_source: [container-run-as-non-root](container-run-as-non-root)_

## P2002: Containers must define resource constraints

**Severity:** Violation

**Resources:** core/Pod apps/DaemonSet apps/Deployment apps/StatefulSet

Resource constraints on containers ensure that a given workload does not take up more resources than it requires
and potentially starve other applications that need to run.

### Rego

```rego
package container_deny_without_resource_constraints

import data.lib.core
import data.lib.pods

policyID := "P2002"

violation[msg] {
  some container
  pods.containers[container]
  not container_resources_provided(container)

  msg := core.format_with_id(
    sprintf("%s/%s/%s: Container resource constraints must be specified", [core.kind, core.name, container.name]),
    policyID,
  )
}

container_resources_provided(container) {
  container.resources.requests.cpu
  container.resources.requests.memory
  container.resources.limits.cpu
  container.resources.limits.memory
}
```

_source: [container-deny-without-resource-constraints](container-deny-without-resource-constraints)_

## P2003: Containers should not have a writable root filesystem

**Severity:** Warning

**Resources:** core/Pod apps/DaemonSet apps/Deployment apps/StatefulSet

In order to prevent persistence in the case of a compromise, it is
important to make the root filesystem read-only.

### Rego

```rego
package container_warn_no_ro_fs

import data.lib.core
import data.lib.pods

policyID := "P2003"

warn[msg] {
  some container
  pods.containers[container]
  no_read_only_filesystem(container)

  msg := core.format_with_id(
    sprintf("%s/%s/%s: Is not using a read only root filesystem", [core.kind, core.name, container.name]),
    policyID,
  )
}

no_read_only_filesystem(container) {
  core.has_field(container.securityContext, "readOnlyRootFilesystem")
  not container.securityContext.readOnlyRootFilesystem
}

no_read_only_filesystem(container) {
  core.missing_field(container.securityContext, "readOnlyRootFilesystem")
}
```

_source: [container-warn-no-ro-fs](container-warn-no-ro-fs)_

