output "environment" {
  description = "Current deployed environment"
  value       = var.environment
}

output "name_prefix" {
  description = "Resource name prefix"
  value       = local.name_prefix
}

# Test PR
output "aws_region" {
  description = "AWS region for resources"
  value       = var.aws_region
}


# ------------------------------------------------------------------------------
# Surface the storage module's outputs at the root level.
#
# Why re-output them? So that:
#   1. Other root-level modules can reference them (e.g. IAM needs bucket ARNs)
#   2. `terraform output` shows them to you after apply
#   3. CI logs and PR comments include them for verification
# ------------------------------------------------------------------------------

output "storage_bucket_names" {
  description = "Names of all S3 buckets created"
  # Note: we're passing through the map, not flattening it to a list.
  # Consumers access specific buckets by logical name.
  value = module.storage.bucket_names
}

output "storage_bucket_arns" {
  description = "ARNs of all S3 buckets created"
  value       = module.storage.bucket_arns
}
