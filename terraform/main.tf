# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.12.0"
    }
  }
}

provider "kubernetes" {
  config_context = var.k8s_config_context
  config_path    = var.k8s_config_path
}

provider "vault" {
  # Configuration options
  address = "http://127.0.0.1:8200"
  token   = "root"
}

provider "helm" {
  kubernetes {
    config_context = var.k8s_config_context
    config_path    = var.k8s_config_path
  }
}

locals {
  vault_namespace = null
  namespace       = "default"
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "vault_mount" "pki" {
  namespace                 = local.vault_namespace
  path                      = var.vault_pki_mount_path
  type                      = "pki"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

resource "vault_pki_secret_backend_role" "role" {
  namespace        = vault_mount.pki.namespace
  backend          = vault_mount.pki.path
  name             = "secret"
  ttl              = 3600
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["example.com"]
  allow_subdomains = true
  allowed_uri_sans = ["uri1.example.com", "uri2.example.com"]
}

resource "vault_pki_secret_backend_root_cert" "test" {
  namespace            = vault_mount.pki.namespace
  backend              = vault_mount.pki.path
  type                 = "internal"
  common_name          = "Root CA"
  ttl                  = "315360000"
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "My OU"
  organization         = "My organization"
}

resource "vault_auth_backend" "default" {
  namespace = local.namespace
  type      = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "default" {
  namespace              = vault_auth_backend.default.namespace
  backend                = vault_auth_backend.default.path
  kubernetes_host        = var.k8s_host
  disable_iss_validation = true
}

resource "vault_kubernetes_auth_backend_role" "default" {
  namespace                        = vault_auth_backend.default.namespace
  backend                          = vault_kubernetes_auth_backend_config.default.backend
  role_name                        = "role1"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = [local.namespace]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.default.name]
}

resource "vault_policy" "default" {
  name   = "dev"
  policy = <<EOT
path "${vault_mount.pki.path}/*" {
  capabilities = ["read", "create", "update"]
}
EOT
}
