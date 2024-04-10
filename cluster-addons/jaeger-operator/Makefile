NAMESPACE = addon-jaeger
NAME      = jaeger

deps:
	helm dep update

install-k8s: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-k8s.yaml --create-namespace

install-kind: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-kind.yaml --create-namespace

install-okd: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-okd.yaml --create-namespace

template-okd: deps
	helm -n $(NAMESPACE) template $(NAME) . -f values-okd.yaml
