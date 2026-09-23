provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  default_tags {
    tags = local.common_tags
  }
}





# ------------------------------------------------------------------------------
# Storage module instantiation.
#
# This is where the "reusable module" pays off. The root module doesn't know
# or care how the storage module builds buckets — it just describes WHAT it
# wants, using the module's input variables.
# ------------------------------------------------------------------------------
module "storage" {
  # Local path to the module. For remote modules this would be a Git URL or
  # a Terraform Registry reference, e.g. "terraform-aws-modules/s3-bucket/aws".
  source = "./modules/storage"

  # Both of these come from root locals.tf, so they're defined once and
  # shared across every module in the project.
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # The map that drives the module. Each key becomes a bucket.
  #
  # The keys ("app", "logs", "backup") are the stable identities. The suffix
  # values ("app", "logs", "backup") just happen to match here, but they
  # don't have to — you could rename a suffix without Terraform recreating
  # the bucket, as long as the key stays the same.
  buckets = {
    app = {
      suffix        = "app"
      force_destroy = true # dev-friendly: allows terraform destroy to wipe it
      # lifecycle_days omitted → defaults to 0 → no lifecycle rule
    }

    logs = {
      suffix         = "logs"
      force_destroy  = false # logs are precious, don't allow accidental deletion
      lifecycle_days = 30    # auto-expire log objects after 30 days
    }

    backup = {
      suffix         = "backup"
      force_destroy  = false
      lifecycle_days = 90 # backups kept longer
    }
  }
}
