#!/bin/bash
set -eu

export KUBECONFIG=/etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-int.kubeconfig

oc get csr -o json \
  | jq -r \
    '.items[] | select(.status.certificate == null) | .metadata.name' \
  | xargs --no-run-if-empty oc adm certificate approve 2>&1
