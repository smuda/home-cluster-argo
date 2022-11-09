REGISTRY_HOST=registry.okd4.example.com
DOCKER_HOST=tcp://192.168.40.20:2376
DOCKER_TLS_VERIFY=1
VOLUME_BASE_PATH=/share/kube-volumes/proxy
VAULT_VERSION=1.12.1
CONTAINER_NAME=dev-vault
VAULT_DEV_TOKEN=myroot

PHONY: vault-cli
vault-cli:
	brew tap hashicorp/tap
	brew install hashicorp/tap/vault

PHONY: pull
pull:
	DOCKER_HOST=$(DOCKER_HOST) \
    DOCKER_TLS_VERIFY=1 \
	docker pull vault:${VAULT_VERSION}

PHONY: clean
clean:
	DOCKER_HOST=$(DOCKER_HOST) \
    DOCKER_TLS_VERIFY=1 \
    docker stop ${CONTAINER_NAME} || echo "Failed to stop"

	DOCKER_HOST=$(DOCKER_HOST) \
    DOCKER_TLS_VERIFY=1 \
    docker rm ${CONTAINER_NAME} || echo "Failed to stop"

	DOCKER_HOST=$(DOCKER_HOST) \
    DOCKER_TLS_VERIFY=1 \
    docker rmi vault:${VAULT_VERSION} || echo "Failed to delete"

PHONY: start
start: pull
	DOCKER_HOST=$(DOCKER_HOST) \
    DOCKER_TLS_VERIFY=1 \
    docker run \
    	--cap-add=IPC_LOCK \
		-d \
		-p 8200:8200 \
		--restart=unless-stopped \
		--name="${CONTAINER_NAME}" \
		-e "VAULT_DEV_ROOT_TOKEN_ID=${VAULT_DEV_TOKEN}" \
		-e 'VAULT_API_ADDR=http://0.0.0.0:8200' \
		-e 'VAULT_LOCAL_CONFIG={"storage": {"file": {"path": "/vault/file"}}, "default_lease_ttl": "168h", "max_lease_ttl": "720h"}' \
		-v "$(VOLUME_BASE_PATH)/hashi-vault/logs":/vault/logs \
		vault:${VAULT_VERSION} \
		server -dev

	sleep 5

	vault login "${VAULT_DEV_TOKEN}"
	vault policy write -tls-skip-verify vault-admin  ./config/local-development/vault-admin-policy.hcl
	#vault auth enable -tls-skip-verify -path cluster1-admin kubernetes
	vault auth enable -tls-skip-verify kubernetes
	vault write -tls-skip-verify auth/cluster1-admin/config kubernetes_host=https://api.ocp4.example.com:6443
