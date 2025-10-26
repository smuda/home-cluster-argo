RELEASE_NAME = test-app
NAMESPACE    = default

.PHONY: install
install:
	oc apply -f application.yaml

.PHONY: remove
remove:
	oc delete application -n argocd helm-pre-install-hook || echo ""
	oc get ns addon-helm-pre-install-hook && oc delete ns addon-helm-pre-install-hook

.PHONY: helm-install
helm-install:
	helm upgrade -i -n $(NAMESPACE) $(RELEASE_NAME) .
