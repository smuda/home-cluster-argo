# Hashicorp vault
This directory contains files for setting up a dev-instance of hashicorp vault, to be used with
Hashicorp Vault config operator.

## Usage

### Install hashicorp vault CLI

```
make vault-cli
```

### Start hashicorp vault

This will start hashicorp vault on the docker instance that is defined in DOCKER_HOST.

```
make start
```

### Stop hashicorp vault

This will stop hashicorp vault on the docker instance that is defined in DOCKER_HOST.

```
make clean
```
