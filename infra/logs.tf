resource "aws_cloudwatch_log_group" "build" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.build.arn
}
