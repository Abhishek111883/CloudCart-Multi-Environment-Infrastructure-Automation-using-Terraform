# ------------------------------------------------------------------------------
# Input variables for the storage module.
#
# Variables are the module's public interface. Anything the root module (or
# another module) needs to pass in must be declared here. Nothing inside this
# module should hardcode values that the caller might want to change.
# ------------------------------------------------------------------------------

variable "name_prefix" {
  # A short string prepended to every bucket name, e.g. "cloudcart-dev".
  # Computed in the root module's locals.tf as "${project}-${environment}".
  # Keeping it as an input means this module doesn't need to know anything
  # about the project name or environment — it just uses whatever it's given.
  description = "Prefix for resource names"
  type        = string
}

variable "buckets" {
  # The heart of the module: a map of bucket definitions.
  #
  # Why a map? Terraform's `for_each` needs either a map or a set of strings
  # to iterate over. A map gives us two things at once:
  #   1. A stable KEY ("app", "logs", "backup") used for resource addressing
  #   2. A VALUE (the object with suffix, force_destroy, etc.)
  #
  # The key is critical. If you rename a bucket's *suffix* but keep the same
  # key, Terraform updates the bucket in place. If you change the *key*,
  # Terraform destroys the old bucket and creates a new one — because to
  # Terraform, a different key means a different resource instance.
  description = "Map of S3 buckets to create, keyed by logical name"
  type = map(object({
    # `suffix` is appended to name_prefix to form the full bucket name.
    # Example: prefix "cloudcart-dev" + suffix "logs" = "cloudcart-dev-logs".
    # We separate suffix from the full name so the prefix stays DRY and
    # consistent across all buckets in this module.
    suffix = string

    # `force_destroy` controls whether Terraform can delete a bucket that
    # still contains objects. In dev/test we usually want true (so teardown
    # is painless). In prod we want false (so a careless `destroy` can't
    # wipe real data). Defaults to false if the caller omits it.
    force_destroy = optional(bool, false)

    # `lifecycle_days` — if > 0, a lifecycle rule is attached to expire
    # objects after that many days. A value of 0 (the default) means "no
    # lifecycle rule at all", which is handled by an `if` filter in main.tf.
    # This is how we make an optional resource without using `count`.
    lifecycle_days = optional(number, 0)
  }))
}

variable "common_tags" {
  # Tags applied to every resource this module creates. Passed in from the
  # root module's locals.tf so tags are defined once, globally, and not
  # repeated in each module.
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
