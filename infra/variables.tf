variable "project_name" {
  description = "CodeBuild project name and prefix for related resources."
  type        = string
  default     = "codebuild-pr-sandbox"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-1"
}

variable "github_owner" {
  description = "GitHub user or org that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "codebuild-pr-sandbox"
}

variable "codeconnection_arn" {
  description = <<-EOT
    ARN of the AWS CodeConnections connection to GitHub (status must be AVAILABLE).
    Create it manually in the AWS console (Developer Tools → Settings → Connections)
    and install the GitHub App on the target repository before running apply.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:codeconnections:[a-z0-9-]+:[0-9]{12}:connection/[0-9a-f-]{36}$", var.codeconnection_arn))
    error_message = "codeconnection_arn must be a valid codeconnections ARN."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log group retention."
  type        = number
  default     = 30
}

variable "build_timeout_minutes" {
  description = "Hard timeout on each build."
  type        = number
  default     = 15
}

variable "queue_timeout_minutes" {
  description = "How long a queued build may wait before abandoning."
  type        = number
  default     = 30
}
