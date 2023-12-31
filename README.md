# vso-apigw
Using Vault Secrets Operator to provide Certs for APIGW Applications

## Overview
The following guide will show a user how to setup a demo environment which uses Vault to issue PKI
certificates to APIGW applications using the Vault Secrets Operator.

**NOTE: This is for demo purposes and is not intended to be used in production, it is highly recommended
to use a Secure configuration of Vault, Consul, and VSO using a combination of TLS, ACLs, and etcd encryption.**

* Install Vault
* Install Consul
* Bootstrap Vault
* Install Vault Secrets Operator
* Deploy VSO Custom Resources
* Deploy APIGW Application


## Required Tools
* Vault 1.11+
* Consul 1.16+
* Terraform 1.4.6+
* Helm 3

Note: This guide assumes that:
- the repository has been cloned locally
- you already have a running Kubernetes cluster
- $PWD is the root of the repository

### Install Consul
```shell
$ helm install consul hashicorp/consul --values consul-values.yaml --version 1.2.0 --namespace consul --create-namespace --wait
```

### Install Vault
```shell
$ helm install vault hashicorp/vault --values vault-values.yaml --version 0.23.0 --wait
# In a separate terminal session, expose Vault on localhost.
# This allows us to program Vault using Terraform below.
$ kubectl port-forward service/vault --namespace default 8200
```

### Bootstrap Vault
Vault must be bootstrapped with the following resources:
* Kubernetes Auth Method, Backend and Role
* PKI Engine and Role
* Supporting Policies to allow access from VSO's service accounts.

```shell
# Using Terraform to apply the bootstrap configuration:
$ cd terraform && terraform init -upgrade && terraform apply -auto-approve && cd ..
<snip>

Plan: 7 to add, 1 to change, 0 to destroy.
vault_auth_backend.default: Creating...
vault_mount.pki: Creating...
kubernetes_namespace.vault: Creating...
vault_auth_backend.default: Creation complete after 0s [id=kubernetes]
vault_mount.pki: Creation complete after 0s [id=pki]
vault_policy.default: Modifying... [id=dev]
vault_kubernetes_auth_backend_config.default: Creating...
vault_pki_secret_backend_role.role: Creating...
vault_pki_secret_backend_root_cert.test: Creating...
kubernetes_namespace.vault: Creation complete after 0s [id=vault]
vault_kubernetes_auth_backend_config.default: Creation complete after 0s [id=auth/kubernetes/config]
vault_policy.default: Modifications complete after 0s [id=dev]
vault_pki_secret_backend_role.role: Creation complete after 0s [id=pki/roles/secret]
vault_kubernetes_auth_backend_role.default: Creating...
vault_kubernetes_auth_backend_role.default: Creation complete after 0s [id=auth/kubernetes/role/role1]
vault_pki_secret_backend_root_cert.test: Creation complete after 1s [id=pki/root/generate/internal]

Apply complete! Resources: 7 added, 1 changed, 0 destroyed.
```

### Install Vault Secrets Operator
Install VSO using the provided `vso-values.yaml`, which contains configuration for the VSO default
VaultAuthMethod and VaultConnection custom resources.

```shell
# Install vault-secrets-operator
$ helm install --values vso-values.yaml --create-namespace --namespace vault-secrets-operator \
vault-secrets-operator hashicorp/vault-secrets-operator --version 0.1.0

NAME: vault-secrets-operator
LAST DEPLOYED: Thu Jun 22 11:56:55 2023
NAMESPACE: vault-secrets-operator
STATUS: deployed
REVISION: 1
```

### Deploy VSO Custom Resources
Apply a VaultPKISecret custom resource which references the Vault PKI Role and destination Kubernetes Secret that
the application will consume.

```shell
$ kubectl apply -f vso-secret.yaml

vaultpkisecret.secrets.hashicorp.com/vaultpkisecret-sample created
```

Confirm that the certificate has been issued by reading the Kubernetes Secret which is created
by the operator:
```shell
$ kubectl get secret pki1 -o json
{
    "apiVersion": "v1",
    "data": {
        "_raw": "<snip>",
        "certificate": "<snip>",
        "expiration": "<snip>",
        "issuing_ca": "<snip>",
        "private_key": "<snip>",
        "private_key_type": "cnNh",
        "serial_number": "NDY6MDM6MjI6MWY6ZTc6N2Q6ZGE6NWI6YzQ6YmQ6ODA6ZmE6YWQ6YTc6ZjE6YTE6MDM6YmI6ODc6N2M="
    },
    "kind": "Secret",
    "metadata": {
        "creationTimestamp": "2023-06-22T16:58:58Z",
        "labels": {
            "app.kubernetes.io/component": "secret-sync",
            "app.kubernetes.io/managed-by": "hashicorp-vso",
            "app.kubernetes.io/name": "vault-secrets-operator",
            "secrets.hashicorp.com/vso-ownerRefUID": "18f65b37-a1da-476e-95d5-4dec74a46ab3"
        },
        "name": "pki1",
        "namespace": "default",
        "ownerReferences": [
            {
                "apiVersion": "secrets.hashicorp.com/v1beta1",
                "kind": "VaultPKISecret",
                "name": "vaultpkisecret-sample",
                "uid": "18f65b37-a1da-476e-95d5-4dec74a46ab3"
            }
        ],
        "resourceVersion": "957",
        "uid": "65210b6c-de1f-42fb-b7a4-236d94b45514"
    },
    "type": "kubernetes.io/tls"
}
```

### Deploy Echo Service
```shell
$ kubectl apply -f echo-service.yaml
```

### Deploy API Gateway Routing to Echo Service
```shell
$ kubectl apply -f api-gateway.yaml
```

### Clean Up
```shell
$ kubectl delete -f api-gateway.yaml && \
    kubectl delete -f echo-service.yaml && \
    kubectl delete -f vso-secret.yaml && \
    helm uninstall vault-secrets-operator -n vault-secrets-operator && \
    cd terraform && terraform destroy -auto-approve && cd .. && \
    helm uninstall vault -n default && \
    helm uninstall consul -n consul
```