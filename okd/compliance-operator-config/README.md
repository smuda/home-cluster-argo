## Rescan

```
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis                compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis-node-master    compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-ocp4-cis-node-worker    compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-rhcos4-moderate-master  compliance.openshift.io/rescan=
oc -n openshift-compliance annotate compliancescans/smuda-rhcos4-moderate-worker  compliance.openshift.io/rescan=
```
