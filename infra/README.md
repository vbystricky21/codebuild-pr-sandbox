# infra/ — Terraform for the GitHub → CodeBuild PR pipeline

## Prerequisites
1. AWS SSO profile configured locally:
   ```
   aws sso login --profile codebuild-sandbox
   ```
2. A CodeConnections connection to GitHub in `AVAILABLE` state, with the
   GitHub App installed on `<owner>/codebuild-pr-sandbox`. Create it in the
   AWS console:
   Developer Tools → Settings → Connections → Create connection → GitHub.
   Complete the handshake in GitHub (install the AWS Connector for GitHub
   app on the repo). Copy the connection ARN.

## Apply

```
cd infra
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # fill in github_owner + codeconnection_arn
```

**Bootstrap step (not in Terraform — the AWS provider doesn't yet
support `aws_codeconnections_repository_link`).** Run once per repo:

```bash
aws codeconnections create-repository-link \
  --connection-arn "$(grep codeconnection_arn terraform.tfvars | awk -F'"' '{print $2}')" \
  --owner-id "$(grep github_owner terraform.tfvars | awk -F'"' '{print $2}')" \
  --repository-name "$(grep github_repo terraform.tfvars | awk -F'"' '{print $2}')" \
  --region eu-west-1 --profile codebuild-sandbox
```

Without this, `terraform apply` fails at `aws_codebuild_webhook` with
`InvalidInputException: Access denied to connection` — CreateWebhook
needs the repository link to resolve the GitHub App installation id for
the repo. This is an undocumented prerequisite for the CodeConnections +
CodeBuild webhook path.

Then:

```
AWS_PROFILE=codebuild-sandbox terraform init
AWS_PROFILE=codebuild-sandbox terraform plan -out=tfplan
AWS_PROFILE=codebuild-sandbox terraform apply tfplan
```

## Teardown

```
AWS_PROFILE=codebuild-sandbox terraform destroy
```

The KMS key has a 7-day deletion window; it will disappear for real after
that.

## Security invariants (do not break)

- `aws_codebuild_webhook.pr` filter uses **anchored** regex (`^…$`). This is
  the mitigation for the CodeBreach superstring-bypass (Jan 2026). If you
  widen the filter, keep the anchors.
- `aws_iam_role_policy.build` contains an **explicit Deny** on
  `codestar-connections:GetConnectionToken` and
  `codeconnections:GetConnectionToken`. This is the mitigation for the
  CodeConnections token-leakage escalation path. A build step running as
  this role cannot extract a raw GitHub App token.
- The role's assume-role policy is scoped to this specific CodeBuild project
  via `aws:SourceArn` / `aws:SourceAccount` — no other CodeBuild project in
  the account can assume it.
- `privileged_mode = false`, `badge_enabled = false`.
- Managed image tag pinned (`aws/codebuild/amazonlinux-x86_64-standard:5.0`).
