# ------------------------------------------------------------------------------
# The actual resources created by the storage module.
#
# All three buckets (app, logs, backup) are created by a SINGLE aws_s3_bucket
# resource using `for_each`. This is the key Terraform pattern to internalise:
# you don't write one resource block per bucket — you write one block and let
# `for_each` produce N instances.
# ------------------------------------------------------------------------------

locals {
  # Transform the incoming `buckets` map into an enriched map that also
  # contains the fully-qualified bucket name.
  #
  # Why do this in locals instead of inline? Three reasons:
  #   1. Readability — the resource block stays clean.
  #   2. Reuse — the same computed name is used by the bucket resource,
  #      the lifecycle resource, and anywhere else we need it.
  #   3. Debuggability — you can `terraform console` and inspect this local.
  #
  # `merge()` combines two maps. Here it takes each bucket's config object
  # and adds a `full_name` attribute computed from the prefix + suffix.
  bucket_map = {
    for name, config in var.buckets :
    name => merge(config, {
      full_name = "${var.name_prefix}-${config.suffix}"
    })
  }
}

# ------------------------------------------------------------------------------
# The S3 buckets themselves.
#
# `for_each = local.bucket_map` creates one aws_s3_bucket per key in the map.
# Each instance is addressed in state as:
#   aws_s3_bucket.this["app"]
#   aws_s3_bucket.this["logs"]
#   aws_s3_bucket.this["backup"]
#
# Inside the block, `each.key` is the map key ("app") and `each.value` is the
# merged object (suffix, force_destroy, lifecycle_days, full_name).
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  for_each = local.bucket_map

  # Use the computed full name, not the raw suffix. Every bucket name in AWS
  # must be globally unique, so prefixing with project+env avoids collisions.
  bucket = each.value.full_name

  # Pulled straight from the caller's map. Controls whether `terraform destroy`
  # can delete a non-empty bucket.
  force_destroy = each.value.force_destroy

  # merge() combines the global common_tags with per-bucket tags.
  # The "Name" tag is what shows up in the AWS console's Name column.
  # The "Role" tag encodes which logical bucket this is (app/logs/backup),
  # which is useful for filtering and cost allocation later.
  tags = merge(var.common_tags, {
    Name = each.value.full_name
    Role = each.key
  })
}

# ------------------------------------------------------------------------------
# Public access block — applied to every bucket.
#
# This is a security baseline. S3 buckets are private by default, but it's
# easy to accidentally loosen that with a bucket policy. Blocking public
# access at the bucket level acts as a hard guardrail: even if someone
# attaches a public policy, AWS will refuse to honour it.
#
# Notice `for_each = aws_s3_bucket.this` — we're iterating over the *resource*
# rather than the local map. That's a common idiom: it guarantees this
# resource is created exactly once per bucket instance, and it gives us
# access to each bucket's computed attributes (like `id`) directly.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Optional lifecycle rules.
#
# Not every bucket needs a lifecycle rule — the app bucket stores artifacts
# we want to keep, while logs and backups benefit from automatic expiry.
#
# The pattern here is "filter the map before iterating". The `for` expression
# below produces a NEW map containing ONLY the buckets whose lifecycle_days
# is greater than zero. If a bucket's lifecycle_days is 0, it won't appear
# in this filtered map, and no lifecycle resource is created for it.
#
# This is how you make a resource "optional" in Terraform without using
# `count = var.enabled ? 1 : 0`, which has its own downsides (index-based
# addressing, awkward with for_each elsewhere).
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # Filter syntax: `for name, config in MAP : name => config if CONDITION`.
  # Only buckets with lifecycle_days > 0 survive this filter.
  for_each = {
    for name, config in local.bucket_map :
    name => config if config.lifecycle_days > 0
  }

  # We reference the bucket by its key, not its full name, so if the naming
  # convention changes later, this resource still points at the right bucket.
  bucket = aws_s3_bucket.this[each.key].id

  rule {
    # A descriptive ID helps when you have multiple lifecycle rules on one
    # bucket. Here we encode the expiry duration so it's self-documenting.
    id     = "expire-after-${each.value.lifecycle_days}-days"
    status = "Enabled"

    # An empty filter block means "apply to all objects in the bucket".
    # Without a filter, some AWS provider versions complain, so we include
    # it explicitly with an empty prefix.
    filter {
      prefix = ""
    }

    # The actual expiry rule: delete objects older than lifecycle_days.
    expiration {
      days = each.value.lifecycle_days
    }
  }
}
