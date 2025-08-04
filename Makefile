
install-kind:
	go install sigs.k8s.io/kind@v0.13.0

start-kind:
	./hack/run-in-kind.sh

stop-kind:
	kind delete cluster --name home-cluster

update-lock:
	find . -name Chart.lock | xargs dirname | xargs -n 1 helm dep update

update-kind-preload:
	KUBECONFIG=~/.kube/home-cluster-argo \
	oc get pod -A -o json \
      | jq -r '.items[].spec.containers[].image' \
      | grep -v docker.io/kindest \
      | grep -v -e "registry.k8s.io/kube-" -e "registry.k8s.io/coredns" -e "registry.k8s.io/etcd" \
      | grep -v -e "registry.k8s.io/ingress-nginx/controller" \
      | grep -v -e "ghcr.io/kro-run/kro/controller" -e "ghcr.io/stakater/reloader" \
      | sort \
      | uniq \
      > ./hack/preload.txt
