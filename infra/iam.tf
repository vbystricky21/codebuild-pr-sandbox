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

  # Post commit status back to GitHub through the CodeConnection.
  # This is the ONE CodeConnections permission the role needs — it does NOT
  # include GetConnectionToken (see explicit deny below).
  statement {
    sid    = "UseConnectionForStatus"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
      "codeconnections:UseConnection",
    ]
    resources = [var.codeconnection_arn]
  }

  # HARD DENY — CodeConnections token leakage mitigation.
  # A raw GitHub App token retrieved from inside a build step would have the
  # full permissions of the GitHub App. This statement blocks that path even
  # if a future allow somehow grants it.
  statement {
    sid     = "DenyGetConnectionToken"
    effect  = "Deny"
    actions = [
      "codestar-connections:GetConnectionToken",
      "codeconnections:GetConnectionToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "${var.project_name}-build"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build_permissions.json
}
