# home-cluster-argo
Starting point for my home clusters

I use ArgoCD for provisioning my home clusters and the first
Application points to this repo under `start`.

That helm chart then installs the other applications which
points for example to `reloader` and `cert-manager`.

# Value-files

The "start" helm chart takes an array value, `argo.common.valueFiles`,
which is propagates to all the other charts.

This is useful for adopting for example OKD specific stuff,
such as removing securityContext, since OKD manages a lot
of that stuff itself.

# Testing

To test this stuff locally in kind, run

```shell
make start-kind 
```

which will start kind, install argocd pointing to this
repository to install the "start" helm chart.

After that you can connect to the argocd GUI:

```shell
kubectl -n argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Authentication is done with 