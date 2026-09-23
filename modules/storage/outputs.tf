# ------------------------------------------------------------------------------
# Outputs expose computed values from this module back to whoever called it.
#
# Notice the pattern: instead of returning a list, we return a MAP keyed by
# the same logical name the caller used in `var.buckets`. So the root module
# can do things like:
#
#   module.storage.bucket_arns["logs"]
#
# ...and get the ARN of the logs bucket specifically. This is far more
# maintainable than positional access like `module.storage.bucket_arns[1]`,
# which breaks the moment you reorder the input map.
# ------------------------------------------------------------------------------

output "bucket_ids" {
  # The `id` of an aws_s3_bucket is the bucket name. Returning it as a map
  # lets callers reference buckets by logical name.
  description = "Map of bucket logical name to bucket ID"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  # ARNs are needed for IAM policies (e.g. allowing a role to write to the
  # logs bucket). Exposing them as a map means the IAM module (Task 4) can
  # consume them without knowing bucket names in advance.
  description = "Map of bucket logical name to bucket ARN"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "bucket_names" {
  # Sometimes you just need the human-readable name (for CLI commands,
  # documentation, or passing to another system).
  description = "Map of bucket logical name to bucket name"
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket }
}
