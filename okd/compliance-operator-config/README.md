## Rescan

```
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis                compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis-node-master    compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis-node-worker    compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-rhcos4-moderate-master  compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-rhcos4-moderate-worker  compliance.openshift.io/rescan=
```

## Security Compliance

When you have installed the Compliance Operator, you can query the results:

```
% oc project openshift-compliance
Now using project "openshift-compliance" on server "https://api.okd4.example.com:6443".

% oc get ComplianceCheckResult -l compliance.openshift.io/check-severity=high,compliance.openshift.io/check-status=FAIL
NAME                                                            STATUS   SEVERITY
ocp4-cis-configure-network-policies-namespaces                  FAIL     high

% oc get ComplianceCheckResult smuda-ocp4-cis-configure-network-policies-namespaces -o yaml
apiVersion: compliance.openshift.io/v1alpha1
description: |-
  Ensure that application Namespaces have Network Policies defined.
  Use network policies to isolate traffic in your cluster network.
id: xccdf_org.ssgproject.content_rule_configure_network_policies_namespaces
instructions: |-
  Verify that the every non-control plane namespace has an appropriate
  NetworkPolicy.

  To get all the non-control plane namespaces, you can do the
  following command $ oc get  namespaces -o json | jq '[.items[] | select((.metadata.name | startswith("openshift") | not) and (.metadata.name | startswith("kube-") | not) and .metadata.name != "default" and (true)) | .metadata.name ]'

  To get all the non-control plane namespaces with a NetworkPolicy, you can do the
  following command $ oc get --all-namespaces networkpolicies -o json | jq '[.items[] | select((.metadata.namespace | startswith("openshift") | not) and (.metadata.namespace | startswith("kube-") | not) and .metadata.namespace != "default" and (true)) | .metadata.namespace] | unique'

  Namespaces matching the variable ocp4-var-network-policies-namespaces-exempt-regex regex are excluded from this check.

  Make sure that the namespaces displayed in the commands of the commands match.
  Is it the case that Namespaced Network Policies needs review?
kind: ComplianceCheckResult
metadata:
  annotations:
    compliance.openshift.io/last-scanned-timestamp: "2024-10-15T01:56:31Z"
    compliance.openshift.io/rule: configure-network-policies-namespaces
  creationTimestamp: "2024-10-13T08:10:23Z"
  generation: 1
  labels:
    compliance.openshift.io/check-severity: high
    compliance.openshift.io/check-status: FAIL
    compliance.openshift.io/profile-guid: a70269f3-e604-55d2-9d28-fa95d40b947a
    compliance.openshift.io/scan-name: smuda-ocp4-cis
    compliance.openshift.io/suite: smuda-binding
  name: smuda-ocp4-cis-configure-network-policies-namespaces
  namespace: openshift-compliance
  ownerReferences:
  - apiVersion: compliance.openshift.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: ComplianceScan
    name: smuda-ocp4-cis
    uid: ec358248-c87a-44ad-820d-d439a433a6aa
  resourceVersion: "354649"
  uid: 98a299d2-d84d-4ae9-91f0-7d878367e3f8
rationale: Running different applications on the same Kubernetes cluster creates a
  risk of one compromised application attacking a neighboring application. Network
  segmentation is important to ensure that containers can communicate only with those
  they are supposed to. When a network policy is introduced to a given namespace,
  all traffic not allowed by the policy is denied. However, if there are no network
  policies in a namespace all traffic will be allowed into and out of the pods in
  that namespace.
severity: high
status: FAIL
```

You can also check the remediations:

```
% oc get ComplianceRemediation              
NAME                                                                   STATE
smuda-ocp4-cis-audit-profile-set                                       NotApplied
smuda-ocp4-cis-kubelet-configure-tls-cipher-suites-ingresscontroller   NotApplied
```



Some cool variables can be found with `oc get variables.compliance`.
