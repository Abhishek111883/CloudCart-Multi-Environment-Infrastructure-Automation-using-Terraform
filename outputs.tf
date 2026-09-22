output "environment" {
  description = "Current deployed environment"
  value       = var.environment
}

output "name_prefix" {
  description = "Resource name prefix"
  value       = local.name_prefix
}
