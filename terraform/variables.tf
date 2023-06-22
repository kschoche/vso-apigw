# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "k8s_config_context" {
  default = "kind-dc1"
}

variable "k8s_config_path" {
  default = "~/.kube/config"
}

variable "k8s_host" {
  default = "https://kubernetes.default.svc"
}

variable "vault_pki_mount_path" {
  default = "pki"
}

variable "operator_namespace" {
  default = "vault-secrets-operator-system"
}

variable "k8s_namespace" {
  default = "vault"
}
