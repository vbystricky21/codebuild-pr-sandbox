data "aws_iam_policy_document" "build_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]

    # Only this CodeBuild project (and this account) can assume the role.
    # Confused-deputy defense — scopes the role tightly.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.project_arn]
    }
  }
}

resource "aws_iam_role" "build" {
  name                 = "${var.project_name}-build"
  assume_role_policy   = data.aws_iam_policy_document.build_trust.json
  max_session_duration = 3600
  description          = "CodeBuild service role for ${var.project_name} (least privilege)."
}

data "aws_iam_policy_document" "build_permissions" {
  # CloudWatch Logs — scoped to this project's log group only.
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [local.log_group_arn]
  }

  # KMS — scoped to the project CMK only.
  statement {
    sid    = "KmsForLogsAndCache"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.build.arn]
  }

  # S3 cache bucket — scoped to this bucket only.
  statement {
    sid    = "S3CacheObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
  statement {
    sid       = "S3CacheBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [aws_s3_bucket.cache.arn]
  }

  # Report groups — so JUnit results can be surfaced in CodeBuild reports.
  statement {
    sid    = "CodeBuildReports"
    effect = "Allow"
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
    ]
    resources = [
      "arn:${local.partition}:codebuild:${local.region}:${local.account_id}:report-group/${var.project_name}-*",
    ]
  }

  # Use the CodeConnection to:
  #   - Register the webhook on GitHub when the project is created
  #   - Clone the source at build time
  #   - Post commit status back on the PR
  #
  # GetConnection + GetConnectionToken are both required for CodeBuild's
  # internal webhook-registration path; UseConnection alone is NOT enough
  # ("Access denied to connection" during CreateWebhook). Scoped to this
  # single connection ARN so a buildspec step can't pivot to other
  # connections in the account.
  statement {
    sid    = "UseConnection"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
      "codestar-connections:GetConnection",
      "codestar-connections:GetConnectionToken",
      "codeconnections:UseConnection",
      "codeconnections:GetConnection",
      "codeconnections:GetConnectionToken",
    ]
    resources = [var.codeconnection_arn]
  }

  # CodeConnections token leakage mitigation.
  #
  # A raw GitHub App token retrieved via *:GetConnectionToken inside a build
  # step would have the full permissions of the AWS Connector GitHub App on
  # the target repo (admin/webhooks/contents). In a standalone AWS account
  # without AWS Organizations, the clean fix (an SCP Deny) is unavailable,
  # and an IAM-level Deny on the CodeBuild service role would also block
  # CodeBuild itself from using the connection for webhook creation and
  # commit-status posting (those paths internally AssumeRole the service
  # role and call GetConnectionToken). We therefore rely on three layered
  # mitigations instead:
  #
  #   1. Scoped allow (below) — only UseConnection on THIS specific
  #      connection ARN, no wildcard; no GetConnectionToken grant here.
  #      AdministratorAccess on callers is outside this role's scope.
  #   2. Branch protection + CODEOWNERS + ruleset require a PR and
  #      thread-resolution before any buildspec.yml change hits main, so
  #      a malicious `aws codeconnections get-connection-token` added to
  #      the buildspec has to pass human review.
  #   3. Pull-request build policy (APPROVERS) in the CodeBuild project
  #      means first-time contributor PRs don't auto-build — untrusted
  #      commits can't execute the buildspec without an existing write
  #      collaborator's consent.
  #
  # If/when this account joins an AWS Organization, add an SCP:
  #   Effect: Deny, Action:
  #     - codestar-connections:GetConnectionToken
  #     - codeconnections:GetConnectionToken
  #   applied to the CodeBuild service role and any non-admin principals.
}

resource "aws_iam_role_policy" "build" {
  name   = "${var.project_name}-build"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build_permissions.json
}
