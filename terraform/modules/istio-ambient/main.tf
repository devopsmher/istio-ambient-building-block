# Istio in ambient mode behind one feature flag.
#   istio-base → istiod → istio-cni → ztunnel, then mesh-wide policy and the shared ingress Gateway.
# No sidecars: ztunnel on every node carries mTLS for the pods of enrolled namespaces.
# Prerequisite: Gateway API CRDs in the cluster (see docs/architecture.md).

locals {
  enabled = var.istio_enabled

  istio = {
    repository = var.istio_repository
    version    = var.istio_version
    namespace  = "istio-system"
  }
}

resource "helm_release" "base" {
  count = local.enabled ? 1 : 0

  name             = "istio-base"
  repository       = local.istio.repository
  chart            = "base"
  version          = local.istio.version
  namespace        = local.istio.namespace
  create_namespace = true
  wait             = true
}

resource "helm_release" "istiod" {
  count = local.enabled ? 1 : 0

  name       = "istiod"
  repository = local.istio.repository
  chart      = "istiod"
  version    = local.istio.version
  namespace  = local.istio.namespace
  wait       = true

  values = [yamlencode({
    profile = "ambient"
    meshConfig = {
      trustDomain   = var.trust_domain
      accessLogFile = "/dev/stdout"
    }
    pilot = {
      env = {
        # Lets namespaces send ingress traffic through their waypoint (istio.io/ingress-use-waypoint),
        # so ingress and mesh traffic pass the same L7 policy. Off by default in istiod.
        ENABLE_INGRESS_WAYPOINT_ROUTING = "true"
      }
    }
  })]

  depends_on = [helm_release.base]
}

resource "helm_release" "cni" {
  count = local.enabled ? 1 : 0

  name       = "istio-cni"
  repository = local.istio.repository
  chart      = "cni"
  version    = local.istio.version
  namespace  = local.istio.namespace
  wait       = true

  values = [yamlencode({
    profile = "ambient"
  })]

  depends_on = [helm_release.istiod]
}

resource "helm_release" "ztunnel" {
  count = local.enabled ? 1 : 0

  name       = "ztunnel"
  repository = local.istio.repository
  chart      = "ztunnel"
  version    = local.istio.version
  namespace  = local.istio.namespace
  wait       = true

  depends_on = [helm_release.cni]
}

# Mesh-wide STRICT mTLS and the shared ingress Gateway, as a small local chart:
# Helm does not need the Istio CRDs at plan time, unlike kubernetes_manifest.
resource "helm_release" "mesh_baseline" {
  count = local.enabled ? 1 : 0

  name      = "mesh-baseline"
  chart     = "${path.module}/charts/mesh-baseline"
  namespace = local.istio.namespace
  wait      = true

  values = [yamlencode({
    rootNamespace = local.istio.namespace
    ingress = {
      enabled       = var.ingress.enabled
      namespace     = var.ingress.namespace
      name          = var.ingress.name
      hostname      = var.ingress.hostname
      tlsSecretName = var.ingress.tls_secret_name
      annotations   = var.ingress.load_balancer_annotations
      certificate = {
        enabled   = var.ingress.certificate_issuer != null
        issuerRef = var.ingress.certificate_issuer
      }
    }
  })]

  depends_on = [helm_release.ztunnel]
}

resource "helm_release" "kiali" {
  count = local.enabled && var.kiali.enabled ? 1 : 0

  name       = "kiali-server"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = var.kiali.version
  namespace  = local.istio.namespace
  wait       = true

  # The OIDC client secret goes into the "kiali" secret in istio-system, outside Terraform state.
  values = [yamlencode({
    auth = {
      strategy = "openid"
      openid = {
        client_id  = var.kiali.oidc_client_id
        issuer_uri = var.kiali.oidc_issuer_url
      }
    }
    external_services = {
      prometheus = {
        url = var.kiali.prometheus_url
      }
    }
  })]

  depends_on = [helm_release.istiod]
}
