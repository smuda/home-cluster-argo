#!/bin/bash

set -eu

KUBE_VERSION=v1.33.1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLUSTER_NAME=home-cluster
KUBECONFIG=~/.kube/${CLUSTER_NAME}-argo
PRE_LOAD_IMAGES_FILE=${SCRIPT_DIR}/preload.txt
INGRESS=${INGRESS:-ingressNginx}
ARGO_PWD=password

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
if ! command -v helm &> /dev/null
then
    echo "helm could not be found"
    exit 1
fi
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found"
    exit 1
fi
if ! command -v argocd &> /dev/null
then
    echo "argocd could not be found"
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
  while read -r image; do
    echo "Checking ${image}"
    # Check if the image exists using Docker manifest inspect
    docker inspect "${image}" > /dev/null 2>&1 \
      || docker pull --platform linux/arm64 --platform linux/amd64 "${image}" \
      || exit 1
  done <"${PRE_LOAD_IMAGES_FILE}"
fi

echo ""
echo "Create cluster"
kind create cluster \
  --config="${SCRIPT_DIR}/kind.yaml" \
  --name "${CLUSTER_NAME}" \
  --kubeconfig "${KUBECONFIG}" \
  --image "kindest/node:${KUBE_VERSION}" \
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
  mkdir -p tmp
  echo ""
  echo "Preload images that we know will be needed from docker.io (minimizing re-pulls)"
  while read -r p; do
    docker save --platform linux/arm64 --platform linux/amd64 "${p}" > tmp/image.tar \
    || exit 1
    kind --name "${CLUSTER_NAME}" load image-archive tmp/image.tar \
    || exit 1
  done <"${PRE_LOAD_IMAGES_FILE}"
fi

echo "Deleting temporary directory"
rm -R tmp || echo "Temporary directory might not exist"

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
  --set "targetRevision=${GIT_REVISION}" \
  --set-string "helmParameters.addons.helmParameters.${INGRESS}.use=true" \
  || exit 1

echo ""
echo "Wait for prometheus CRD installation"
while ! kubectl \
  --kubeconfig "${KUBECONFIG}" \
  wait \
  --for condition=established \
  --timeout=300s \
  crd/servicemonitors.monitoring.coreos.com
do
  echo "Try again"
  sleep 5
done

echo ""
echo "Wait for cert-manager CRD installation"
while ! kubectl \
  --kubeconfig "${KUBECONFIG}" \
  wait \
  --for condition=established \
  --timeout=300s \
  crd/certificates.cert-manager.io
do
  echo "Try again"
  sleep 5
done

if [[ ${INGRESS} == "ingressNginx" ]]; then
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
fi

if [[ ${INGRESS} == "nginxIngress" ]]; then
  echo ""
  echo "Wait for nginx-ingress"
  while ! kubectl \
   --kubeconfig "${KUBECONFIG}" \
   --namespace=addon-nginx-ingress \
    wait deployment nginx-ingress-upstream-controller \
    --for condition=Available=True \
    --timeout=120s
  do
    echo "Try again"
    sleep 5
  done
fi


echo ""
echo "Configure argocd cli"
echo ""
ARGO_HOST=$(kubectl --kubeconfig "${KUBECONFIG}" \
  -n argocd \
  get ingress argocd-server -o json | jq -r '.spec.rules[0].host') \
  || exit 1

argocd configure \
  --kube-context "$(kubectl config current-context)" \
  --server "${ARGO_HOST}" \
  || exit 1

echo "Login with argocd cli (password ${ARGO_PWD}"
argocd login \
  --insecure \
  "${ARGO_HOST}" \
  --grpc-web \
  --username admin \
  --password "${ARGO_PWD}" \
  || exit 1

echo ""
echo "Wait for cert-manager to install successfully"
KUBECONFIG=${KUBECONFIG} \
kubectl config set-context --current --namespace=argocd
while ! argocd app wait argocd/addon-cert-manager --grpc-web > /dev/null
do
  echo "Try again"
  sleep 5
done

echo ""
echo "Wait for cert-manager to start"
DEPLOYMENTS=$(kubectl \
  --kubeconfig "${KUBECONFIG}" \
  -n addon-cert-manager \
  get deploy -o json | jq -r '.items[].metadata.name' | tr '\n' ' ')

kubectl \
 --kubeconfig "${KUBECONFIG}" \
 --namespace=addon-cert-manager \
  wait deployment ${DEPLOYMENTS} \
  --for condition=Available=True \
  --timeout=180s \
  || exit 1

echo ""
echo "Wait for cert-manager-approver-policy to install successfully"
while ! argocd app wait argocd/addon-cert-manager-approver-policy --grpc-web > /dev/null
do
  echo "Try again"
  sleep 5
done
echo "Wait for cert-manager-config to install successfully"
while ! argocd app wait argocd/addon-cert-manager-config --grpc-web > /dev/null
do
  echo "Try again"
  sleep 5
done
kubectl -n addon-cert-manager delete certificate lab-issuer > /dev/null \
  || exit 1
sleep 1
kubectl delete clusterissuer lab-cluster-issuer \
  || exit 1
sleep 1

echo ""
echo "Install argocd again, which means we will get metrics and cert-manager certificate"
helm --kubeconfig "${KUBECONFIG}" \
  upgrade -n argocd \
  argocd ./argo-install \
  --set argo-cd.server.certificate.enabled=true \
  --set argo-cd.server.certificate.issuer.kind=ClusterIssuer \
  --set argo-cd.server.certificate.issuer.name=lab-cluster-issuer \
  || exit 1

echo "You can now login to argo with https://${ARGO_HOST} using admin and ${ARGO_PWD:-password}"
kubectl config set-context --current --namespace=default
