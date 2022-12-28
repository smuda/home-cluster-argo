#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
KUBECONFIG=~/.kube/home-cluster-argo

pushd "${SCRIPT_DIR}" \
  || exit 1

touch "${KUBECONFIG}" || exit 1

echo ""
echo "Delete cluster if it exists"
kind delete cluster --name home-cluster \
  || exit 1

echo ""
GIT_REVISION=$(git rev-parse --abbrev-ref HEAD)
echo "Current git branch is ${GIT_REVISION}"

echo ""
echo "Create cluster"
kind create cluster \
  --config="${SCRIPT_DIR}/kind.yaml" \
  --name home-cluster \
  --kubeconfig "${KUBECONFIG}" \
  --wait 120s \
  || exit 1

chmod 600 "${KUBECONFIG}" || exit 1

echo ""
echo "Wait for cluster to start"
while ! kubectl --kubeconfig "${KUBECONFIG}" cluster-info
do
  echo "Try again"
  sleep 5
done

echo ""
echo "Create argocd namespace"
kubectl --kubeconfig "${KUBECONFIG}" \
  create namespace argocd \
  || exit 1

echo ""
echo "Install argocd"
kubectl --kubeconfig "${KUBECONFIG}" \
  apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  || exit 1

echo ""
echo "Wait for argocd to start"
DEPLOYMENTS=$(kubectl --kubeconfig "${KUBECONFIG}" -n argocd get deploy -o json | jq -r '.items[].metadata.name' | tr '\n' ' ')

kubectl \
 --kubeconfig "${KUBECONFIG}" \
 --namespace=argocd \
  wait deployment ${DEPLOYMENTS} \
  --for condition=Available=True \
  --timeout=120s \
  || exit 1

echo ""
echo "Prepare for sealed-secrets"
kubectl \
  --kubeconfig "${KUBECONFIG}" \
  apply -f "${SCRIPT_DIR}/sealed-secrets-secret.yml" \
  || exit 1

echo ""
echo "Install application"
helm --kubeconfig "${KUBECONFIG}" \
  --namespace=argocd \
  upgrade -i start start \
  -f start/values-kind.yaml \
  --set "targetRevision=${GIT_REVISION}"
