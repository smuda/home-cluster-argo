# METADATA
# title: Containers must not run as root
# description: |-
#   Running containers as root can allow too much rights on the node.
#   As such, they are not allowed.
# custom:
#   enforcement: deny
#   matchers:
#     kinds:
#     - apiGroups:
#       - ""
#       kinds:
#       - Pod
#     - apiGroups:
#       - apps
#       kinds:
#       - DaemonSet
#       - Deployment
#       - StatefulSet
#   annotations:
#     "argocd.argoproj.io/sync-options": "SkipDryRunOnMissingResource=true"
#     "argocd.argoproj.io/sync-wave": "1"
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
