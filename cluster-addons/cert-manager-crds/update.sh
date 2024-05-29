#!/usr/bin/env bash

set -eu

echo "Verify binaries exist"
if ! command -v sed &> /dev/null
then
    echo "sed could not be found"
    exit 1
fi
if ! command -v curl &> /dev/null
then
    echo "curl could not be found"
    exit 1
fi
if ! command -v kubectl krew &> /dev/null
then
    echo "kubectl krew could not be found, see https://krew.sigs.k8s.io/docs/user-guide/setup/install/"
    exit 1
fi
if ! command -v kubectl-slice &> /dev/null
then
    echo "kubectl-slice could not be found. Try kubectl krew install slice"
    exit 1
fi

# Find out the current version of cert-manager
VERSION=$(cat ../cert-manager/Chart.yaml | grep "^    version: " | sed 's|    version: ||')

echo "Version: ${VERSION}"

# Fetch the CRDs from github
URL=https://github.com/cert-manager/cert-manager/releases/download/${VERSION}/cert-manager.crds.yaml
echo "Fetching from ${URL}"
curl -L "${URL}" | kubectl-slice --output-dir=./templates --template '{{.metadata.name|dottodash}}.yaml'
