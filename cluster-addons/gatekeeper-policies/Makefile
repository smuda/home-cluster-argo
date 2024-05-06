NAMESPACE := addon-gatekeeper
NAME := gatekeeper-policies
KONSTRAINT_VERSION := v0.36.0

install-k8s:
	helm -n "$(NAMESPACE)" \
		upgrade -i \
		"$(NAME)" \
		 . \
		 -f values-k8s.yaml

install-kind:
	helm -n "$(NAMESPACE)" \
		upgrade -i \
		"$(NAME)" \
		 . \
		 -f values-kind.yaml

install-okd:
	helm -n "$(NAMESPACE)" \
		upgrade -i \
		"$(NAME)" \
		 . \
		 -f values-okd.yaml

.PHONY: policies
policies: tool-konstraint
	konstraint create policies --output templates/policies

.PHONY: docs
docs: tool-konstraint
	konstraint doc policies --output policies/policies.md

.PHONY: tool-konstraint
tool-konstraint:
ifeq (, $(shell which konstraint))
	go install "github.com/plexsystems/konstraint@$(KONSTRAINT_VERSION)"
endif
