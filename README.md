# vso-apigw
Using Vault Secrets Operator to provide Certs for APIGW Applications

## Overview
The following guide will show a user how to setup a demo environment which uses Vault to issue PKI certificates
to APIGW applications using the Vault Secrets Operator.

-> **NOTE:** This is for demo purposes and is not intended to be used in production, it is highly recommended
to use a Secure configuration of Vault, Consul, and VSO using a combination of TLS, ACLs and encryption.

* Install Vault
* Install Consul with APIGW enabled
* Bootstrap Vault
* Install Vault Secrets Operator
* Deploy VSO Custom Resources
* Deploy APIGW Application


## Pre-Requisites
* Kind
* Kubernetes 1.25+
* Vault 1.11+
* Consul 1.16+
* Terraform 1.11+
* Helm3

### Setup Kind Cluster [Optional]
```shell
$ kind create cluster \
        --wait=5m \
        --name=dc1 \
        --config=kind-config.yaml \
        --image=kindest/node:v1.25.3
```

### Install Vault
```shell
$ helm install vault hashicorp/vault --values vault-values.yaml --version 0.23.0 --wait
# This allows a hostPort path to be defined on the vault server for demo purposes.
$ kubectl patch --namespace=default statefulset vault --patch-file ./patch.yaml
# This restarts the vault pod to pick up the patch.
$ kubectl delete pod vault-0
# Wait for vault to come back online (READY).
```

### Install Consul with APIGW enabled


### Bootstrap Vault
Vault must be bootstrapped with the following resources:
* Kubernetes Auth Method, Backend and Role
* PKI Engine and Role
* Supporting Policies to allow access from VSO's service accounts.

```shell
# Using Terraform to apply the bootstrap configuration:
$ cd terraform && terraform apply .
```

### Install Vault Secrets Operator
Install VSO using the provided `vso-values.yaml`, which contains configuration for the VSO default
VaultAuthMethod and VaultConnection custom resources.

```shell
$ helm install --values vso-values.yaml --create-namespace --namespace vault-secrets-operator \
vault-secrets-operator hashicorp/vault-secrets-operator --version 0.1.0
```

### Deploy VSO Custom Resources
Apply the VaultPKISecret custom resource.

```shell
$ kubectl apply -f vso-secret.yaml
```

### Deploy APIGW Application



