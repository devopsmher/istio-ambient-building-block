# Example: install the mesh on an existing EKS cluster behind the feature flag.
# Credentials come from the AWS CLI at run time (aws eks get-token): no static tokens in state.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
    }
  }
}

variable "cluster_name" {
  description = "Existing EKS cluster."
  type        = string
}

variable "region" {
  description = "AWS region of the cluster."
  type        = string
}

variable "istio_enabled" {
  description = "Turn the mesh on for this cluster."
  type        = bool
  default     = false
}

provider "aws" {
  region = var.region
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

module "mesh" {
  source = "../../modules/istio-ambient"

  istio_enabled = var.istio_enabled

  ingress = {
    hostname = "*.payments-dev.example.com"
    certificate_issuer = {
      name = "letsencrypt-dns"
    }
  }
}

output "ingress_gateway" {
  value = module.mesh.ingress_gateway
}
