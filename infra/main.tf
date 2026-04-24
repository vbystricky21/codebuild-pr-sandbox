provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Environment = "sandbox"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  partition      = data.aws_partition.current.partition
  region         = data.aws_region.current.name
  project_arn    = "arn:${local.partition}:codebuild:${local.region}:${local.account_id}:project/${var.project_name}"
  log_group_name = "/aws/codebuild/${var.project_name}"
  # Bare log group ARN — used for kms:EncryptionContext matching.
  log_group_arn_bare = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}"
  # ARN + ":*" — used for IAM resource matching on log streams.
  log_group_arn = "${local.log_group_arn_bare}:*"
  github_url    = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}
