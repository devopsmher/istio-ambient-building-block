variable "istio_enabled" {
  description = "Feature flag for the whole mesh. Off by default: a cluster opts in, and namespaces still join one by one."
  type        = bool
  default     = false
}

variable "istio_version" {
  description = "Istio release for every component. Upgrade one minor version at a time."
  type        = string
  default     = "1.31.4"
}

variable "istio_repository" {
  description = "Helm repository with the official Istio charts."
  type        = string
  default     = "https://blob.istio.io/istio-release/charts"
}

variable "trust_domain" {
  description = "SPIFFE trust domain. Workload identities look like <trust_domain>/ns/<namespace>/sa/<service account>."
  type        = string
  default     = "cluster.local"
}

variable "ingress" {
  description = "Shared ingress Gateway. Teams attach HTTPRoutes to it from namespaces labelled for ingress."
  type = object({
    enabled         = optional(bool, true)
    namespace       = optional(string, "istio-ingress")
    name            = optional(string, "public")
    hostname        = string
    tls_secret_name = optional(string, "public-gateway-tls")
    certificate_issuer = optional(object({
      kind = optional(string, "ClusterIssuer")
      name = string
    }))
    load_balancer_annotations = optional(map(string), {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    })
  })
}

variable "kiali" {
  description = "Kiali with single sign-on through an OpenID Connect provider."
  type = object({
    enabled         = optional(bool, false)
    version         = optional(string, "2.34.1")
    oidc_issuer_url = optional(string, "")
    oidc_client_id  = optional(string, "kiali")
    prometheus_url  = optional(string, "http://prometheus-operated.monitoring:9090")
  })
  default = {}

  validation {
    condition     = !var.kiali.enabled || var.kiali.oidc_issuer_url != ""
    error_message = "Kiali needs oidc_issuer_url: this module never exposes Kiali without single sign-on."
  }
}
