output "codebuild_project_name" {
  description = "Name of the CodeBuild project."
  value       = aws_codebuild_project.pr.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project."
  value       = aws_codebuild_project.pr.arn
}

output "build_role_arn" {
  description = "Service role used by CodeBuild."
  value       = aws_iam_role.build.arn
}

output "kms_key_arn" {
  description = "CMK encrypting CodeBuild logs and cache."
  value       = aws_kms_key.build.arn
}

output "cache_bucket" {
  description = "S3 bucket used for Gradle caching."
  value       = aws_s3_bucket.cache.bucket
}

output "log_group_name" {
  description = "CloudWatch log group for build logs."
  value       = aws_cloudwatch_log_group.build.name
}

output "webhook_url" {
  description = "Webhook URL registered on the repository (via CodeConnections)."
  value       = aws_codebuild_webhook.pr.payload_url
  sensitive   = true
}
