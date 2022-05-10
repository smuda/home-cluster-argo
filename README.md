# home-cluster-argo
Starting point for my home clusters

I use ArgoCD for provisioning my home clusters and the first
Application points to this repo under `start`.

That helm chart then installs the other applications which
points for example to `reloader` and `cert-manager`.
