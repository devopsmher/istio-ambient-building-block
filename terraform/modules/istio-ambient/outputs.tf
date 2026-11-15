output "enabled" {
  description = "Whether the mesh is installed."
  value       = local.enabled
}

output "istio_version" {
  description = "Installed Istio release."
  value       = local.enabled ? var.istio_version : null
}

output "ingress_gateway" {
  description = "Shared Gateway that team HTTPRoutes attach to."
  value = local.enabled && var.ingress.enabled ? {
    name      = var.ingress.name
    namespace = var.ingress.namespace
  } : null
}
