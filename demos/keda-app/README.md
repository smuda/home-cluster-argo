# App for verifying KEDA functionality

## Installation

helm install keda-app .

# Load testing

k6 run k6/perf-30.js

# How it works

metric ´rate(http_requests_total{namespace="okd-keda-app"} [30s])´

kube_deployment_spec_replicas{namespace="okd-keda-app"}