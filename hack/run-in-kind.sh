#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLUSTER_NAME=home-cluster
KUBECONFIG=~/.kube/${CLUSTER_NAME}-argo
PRE_LOAD_IMAGES_FILE=${SCRIPT_DIR}/preload.txt

echo "Verify binaries exist"
if ! command -v jq &> /dev/null
then
    echo "jq could not be found"
    exit 1
fi
if ! command -v kind &> /dev/null
then
    echo "kind could not be found"
    exit 1
fi
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found"
    exit 1
fi

pushd "${SCRIPT_DIR}" \
  || exit 1

touch "${KUBECONFIG}" || exit 1

echo ""
echo "Delete cluster if it exists"
kind delete cluster --name "${CLUSTER_NAME}" \
  || exit 1

echo ""
GIT_REVISION=$(git rev-parse --abbrev-ref HEAD)
echo "Current git branch is ${GIT_REVISION}"

if test -f "${PRE_LOAD_IMAGES_FILE}"; then
  echo ""
  echo "Pull images that we know will be needed from docker.io (minimizing re-pulls)"
  while read -r p; do
    docker pull  "$p" \
      || exit 1
  done <"${PRE_LOAD_IMAGES_FILE}"
fi

echo ""
echo "Create cluster"
kind create cluster \
  --config="${SCRIPT_DIR}/kind.yaml" \
  --name "${CLUSTER_NAME}" \
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

if test -f "${PRE_LOAD_IMAGES_FILE}"; then
  echo ""
  echo "Preload images that we know will be needed from docker.io (minimizing re-pulls)"
  while read -r p; do
    kind --name "${CLUSTER_NAME}" \
      load docker-image "$p" \
      || exit 1
  done <"${PRE_LOAD_IMAGES_FILE}"
fi

echo ""
echo "Create argocd namespace"
kubectl --kubeconfig "${KUBECONFIG}" \
  create namespace argocd \
  || exit 1

echo ""
echo "Install argocd"
helm dependency update \
  ./argo-install \
  || exit 1
helm --kubeconfig "${KUBECONFIG}" \
  install -n argocd \
  argocd ./argo-install \
  || exit 1

echo ""
echo "Wait for argocd to start"
DEPLOYMENTS=$(kubectl \
  --kubeconfig "${KUBECONFIG}" \
  -n argocd \
  get deploy -o json | jq -r '.items[].metadata.name' | tr '\n' ' ')

kubectl \
 --kubeconfig "${KUBECONFIG}" \
 --namespace=argocd \
  wait deployment ${DEPLOYMENTS} \
  --for condition=Available=True \
  --timeout=180s \
  || exit 1

SEALED_FILE="${SCRIPT_DIR}/sealed-secrets-secret.yml"
if test -f "${SEALED_FILE}"; then
  echo ""
  echo "Prepare for sealed-secrets"
  kubectl \
    --kubeconfig "${KUBECONFIG}" \
    apply -f "${SEALED_FILE}" \
    || exit 1
fi

echo ""
echo "Install application"
helm \
  --kubeconfig "${KUBECONFIG}" \
  --namespace=argocd \
  upgrade -i start start \
  -f start/values-kind.yaml \
  --set "targetRevision=${GIT_REVISION}"

echo "Wait for prometheus CRD installation"
while ! kubectl \
  --kubeconfig "${KUBECONFIG}" \
  wait --for condition=established --timeout=300s \
  crd/servicemonitors.monitoring.coreos.com
do
  echo "Try again"
  sleep 5
done

echo ""
echo "Install argocd again, which means we will get metrics"
helm --kubeconfig "${KUBECONFIG}" \
  upgrade -n argocd \
  argocd ./argo-install \
  || exit 1

echo ""
echo "Wait for ingress-nginx"
while ! kubectl \
 --kubeconfig "${KUBECONFIG}" \
 --namespace=addon-ingress-nginx \
  wait deployment ingress-nginx-upstream-controller \
  --for condition=Available=True \
  --timeout=120s
do
  echo "Try again"
  sleep 5
done

echo ""
ARGO_PWD=$(kubectl --kubeconfig "${KUBECONFIG}" \
  -n argocd \
  get secret argocd-secret -o jsonpath="{.data.'admin.password'}" | base64 -d)
ARGO_HOST=$(kubectl --kubeconfig "${KUBECONFIG}" \
  -n argocd \
  get ingress argocd-server-ingress -o json | jq -r '.spec.rules[0].host')

echo "You can now login to argo with https://${ARGO_HOST} using admin and ${ARGO_PWD:-password}"
