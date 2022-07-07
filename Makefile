
install-kind:
	go install sigs.k8s.io/kind@v0.13.0

start-kind:
	./hack/run-in-kind.sh

stop-kind:
	kind delete cluster --name home-cluster
