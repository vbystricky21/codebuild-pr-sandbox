resource "aws_codebuild_project" "pr" {
  name           = var.project_name
  description    = "Runs ./gradlew test on pull requests to ${var.github_owner}/${var.github_repo}."
  service_role   = aws_iam_role.build.arn
  build_timeout  = var.build_timeout_minutes
  queued_timeout = var.queue_timeout_minutes
  badge_enabled  = false
  encryption_key = aws_kms_key.build.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.cache.bucket}/gradle"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.build.name
    }
    s3_logs {
      status = "DISABLED"
    }
  }

  # NOTE: We intentionally omit the `source.auth` block.
  # AWS CodeBuild uses the account-level source credential established via
  # `aws codebuild import-source-credentials --auth-type CODECONNECTIONS
  # --server-type GITHUB --token <connection_arn>`. That one-time import
  # binds the connection ARN to the account/region and CodeBuild then uses
  # it implicitly for every GITHUB source in that account/region.
  #
  # Attempting to specify `source.auth { type = "CODECONNECTIONS" }` here
  # produces OAuthProviderException: "User is not authorized to access
  # connection" even when IAM clearly allows PassConnection. This is an
  # AWS quirk; the imported credential path is the supported one today.
  source {
    type                = "GITHUB"
    location            = local.github_url
    buildspec           = "buildspec.yml"
    git_clone_depth     = 1
    report_build_status = true

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = "refs/heads/main"

  depends_on = [
    aws_iam_role_policy.build,
    aws_codebuild_source_credential.github,
  ]
}

# Webhook — PR events only, with ANCHORED regex on BASE_REF.
# The leading "^" / trailing "$" are the mitigation for the CodeBreach
# superstring-bypass disclosed January 2026. Do NOT remove the anchors.
resource "aws_codebuild_webhook" "pr" {
  project_name = aws_codebuild_project.pr.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
    }
    filter {
      type    = "BASE_REF"
      pattern = "^refs/heads/main$"
    }
  }
}
