VERSION=1.4.0

rm manifests/*
curl -L \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v${VERSION}/standard-install.yaml \
  -o manifests/standard-install-${VERSION}.yaml
