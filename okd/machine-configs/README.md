# OKD Machine Configs

# Forcing machine configs

When playing around with machine configs it's very easy to have the node get stuck in
the update. 

Especially with the kubeletconfig, the problem can be detected by using

```shell
journalctl -b -u kubelet
```

After fixing the problematic machine config, you can force the new to
apply by using

```shell
sudo touch /run/machine-config-daemon-force
```

# butane 
Using `content: inline:` in a machine config does not seem to always work as expected.

Therefore, a number of machine configs (especially in the system folder) are generated with `butane`.
However, the resulting template is used for multiple machine config pools, so care must be
taken when updating the content.

Run butane to update the yaml file:

```shell
butane --strict templates/system/99-chrony-master.bu -o templates/system/99-chrony.yaml
```

Then use git to restore helm variables.

## Security Compliance

When you have installed the Compliance Operator, you can query the results:

```
% oc project openshift-compliance
Now using project "openshift-compliance" on server "https://api.okd4.example.com:6443".
% oc get ComplianceCheckResult -l compliance.openshift.io/check-severity=high,compliance.openshift.io/check-status=FAIL
NAME                                                            STATUS   SEVERITY
ocp4-cis-configure-network-policies-namespaces                  FAIL     high

% oc get ComplianceCheckResult ocp4-cis-configure-network-policies-namespaces  -o yaml                                 
apiVersion: compliance.openshift.io/v1alpha1
description: |-
  Ensure that application Namespaces have Network Policies defined.
  Running different applications on the same Kubernetes cluster creates a risk of one
  compromised application attacking a neighboring application. Network segmentation is
  important to ensure that containers can communicate only with those they are supposed
  to. When a network policy is introduced to a given namespace, all traffic not allowed
  by the policy is denied. However, if there are no network policies in a namespace all
  traffic will be allowed into and out of the pods in that namespace.
id: xccdf_org.ssgproject.content_rule_configure_network_policies_namespaces
instructions: |-
  Verify that the every non-control plane namespace has an appropriate
  NetworkPolicy.

  To get all the non-control plane namespaces, you can do the
  following command oc get  namespaces -o json | jq '[.items[] | select((.metadata.name | startswith("openshift") | not) and (.metadata.name | startswith("kube-") | not) and .metadata.name != "default") | .metadata.name ]'

  To get all the non-control plane namespaces with a NetworkPolicy, you can do the
  following command oc get --all-namespaces networkpolicies -o json | jq '[.items[] | select((.metadata.namespace | startswith("openshift") | not) and (.metadata.namespace | startswith("kube-") | not) and .metadata.namespace != "default") | .metadata.namespace] | unique'

  Make sure that the namespaces displayed in the commands of the commands match.
kind: ComplianceCheckResult
metadata:
  annotations:
    compliance.openshift.io/rule: configure-network-policies-namespaces
  creationTimestamp: "2022-09-13T05:05:01Z"
  generation: 1
  labels:
    compliance.openshift.io/check-severity: high
    compliance.openshift.io/check-status: FAIL
    compliance.openshift.io/scan-name: ocp4-cis
    compliance.openshift.io/suite: cis-compliance
  name: ocp4-cis-configure-network-policies-namespaces
  namespace: openshift-compliance
  ownerReferences:
  - apiVersion: compliance.openshift.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: ComplianceScan
    name: ocp4-cis
    uid: 8989824e-2de8-4fc1-a0a4-ef7806a0ed52
  resourceVersion: "49968"
  uid: 96fd985b-e738-43f6-b302-3ed625510848
severity: high
status: FAIL
```

You can also check the remediations:

```
% oc get ComplianceRemediation              
NAME                                                                 STATE
ocp4-cis-api-server-encryption-provider-cipher                       Applied
ocp4-cis-api-server-encryption-provider-config                       Applied
ocp4-cis-kubelet-configure-event-creation                            Error
ocp4-cis-kubelet-configure-event-creation-1                          Error
ocp4-cis-kubelet-configure-tls-cipher-suites                         Error
ocp4-cis-kubelet-configure-tls-cipher-suites-1                       Error
ocp4-cis-kubelet-enable-iptables-util-chains                         Error
ocp4-cis-kubelet-enable-iptables-util-chains-1                       Error
ocp4-cis-kubelet-enable-streaming-connections                        Error
ocp4-cis-kubelet-enable-streaming-connections-1                      Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-available      Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-available-1    Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-available-2    Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-available-3    Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-inodesfree     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-inodesfree-1   Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-inodesfree-2   Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-imagefs-inodesfree-3   Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-memory-available       Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-memory-available-1     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-memory-available-2     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-memory-available-3     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-available       Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-available-1     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-available-2     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-available-3     Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-inodesfree      Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-inodesfree-1    Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-inodesfree-2    Error
ocp4-cis-kubelet-eviction-thresholds-set-hard-nodefs-inodesfree-3    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available      Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available-1    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available-2    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available-3    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available-4    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-available-5    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree-1   Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree-2   Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree-3   Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree-4   Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-imagefs-inodesfree-5   Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available       Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available-1     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available-2     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available-3     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available-4     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-memory-available-5     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available       Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available-1     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available-2     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available-3     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available-4     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-available-5     Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree      Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree-1    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree-2    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree-3    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree-4    Error
ocp4-cis-kubelet-eviction-thresholds-set-soft-nodefs-inodesfree-5    Error
ocp4-cis-node-master-kubelet-enable-protect-kernel-defaults          MissingDependencies
ocp4-cis-node-master-kubelet-enable-protect-kernel-sysctl            Applied
ocp4-cis-node-worker-kubelet-enable-protect-kernel-defaults          MissingDependencies
ocp4-cis-node-worker-kubelet-enable-protect-kernel-sysctl            Applied
```



Some cool variables can be found with `oc get variables.compliance`.
