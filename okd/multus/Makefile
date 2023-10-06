HELM_NAME := multus-test

install: upgrade

upgrade:
	@helm upgrade -i $(HELM_NAME) . -f values-okd.yaml

POD := $(shell oc get pod -l app=whereabouts -o json | jq -r '.items[0].metadata.name')

exec:
	echo "Pod=$(POD)"
	@oc exec -it $(POD) -- sh
