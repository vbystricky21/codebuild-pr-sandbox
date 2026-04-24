# Account-level CodeBuild source credential binding the CodeConnections
# GitHub App connection to this account/region. Required because passing
# the connection ARN directly in `aws_codebuild_project.source.auth`
# fails with OAuthProviderException ("User is not authorized to access
# connection") under the new codeconnections:* permission model.
#
# Exactly one of these exists per account+region+server_type. The webhook
# filter + service role still enforce the per-project scope.
resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = var.codeconnection_arn
}
