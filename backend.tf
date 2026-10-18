# State lives in a Cloudflare R2 bucket (S3-compatible), separate from
# hephaistos-rs's bucket so the two can never collide. Nothing secret is
# committed here:
#
#   AWS_ENDPOINT_URL_S3    https://<account-id>.r2.cloudflarestorage.com
#   AWS_ACCESS_KEY_ID      R2 API token access key
#   AWS_SECRET_ACCESS_KEY  R2 API token secret
#
# Bucket and key below are placeholders — change them once the bucket
# exists (see README "Bootstrap"). Keep the key distinct from
# hephaistos-rs's "org-state.tfstate" in its own bucket; this bucket name
# alone already prevents a collision, but a tbxkit-specific key is kept
# too in case the bucket is ever shared.

terraform {
  backend "s3" {
    bucket       = "tbxkit-tofu-state" # created via wrangler r2 bucket create, 2026-10-18
    key          = "org-state.tfstate"
    region       = "auto"
    use_lockfile = true

    # R2 is not AWS: skip the AWS-only checks and use path-style URLs.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
