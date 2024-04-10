#!/bin/bash

pushd kustomize > /dev/null || exit 1

cat <&0 > all.yaml

kustomize build . && rm all.yaml
