NAMESPACE = addon-keptn
NAME      = keptn-config

deps:
	helm dep update

install-k8s: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-k8s.yaml

install-kind: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-kind.yaml

install-okd: deps
	helm -n $(NAMESPACE) upgrade -i $(NAME) . -f values-okd.yaml

template-okd: deps
	helm -n $(NAMESPACE) template $(NAME) . -f values-okd.yaml
