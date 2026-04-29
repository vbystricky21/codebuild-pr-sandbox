# codebuild-pr-sandbox

Trivial Java 21 + Gradle project used to exercise the GitHub ↔ AWS CodeBuild
pull-request integration end-to-end.

## Local

```
./gradlew --no-daemon test
```


Requires a JDK to launch Gradle; the Gradle toolchain will download
Adoptium JDK 21 on first run for compilation.

## Pipeline

Every pull request opened against `main` triggers the `codebuild-pr-sandbox`
AWS CodeBuild project (region `eu-west-1`). The build runs
`./gradlew --no-daemon test` and posts commit status back to GitHub via
the AWS CodeConnections GitHub App. `main` is branch-protected and requires
the green status check before merge.

## Infra

Terraform under [`infra/`](infra/). See [`infra/README.md`](infra/README.md)
for apply/destroy instructions.

## Security notes

See the plan file for the full threat model; highlights:

- Webhook filters are **anchored** (`^`/`$`) — mitigates CodeBreach superstring bypass.
- CodeBuild service role **explicitly denies** `codestar-connections:GetConnectionToken`
  and `codeconnections:GetConnectionToken` — mitigates the CodeConnections
  token-leakage escalation.
- Pull-request build policy is `APPROVERS` — first-time contributor PRs do
  not auto-build.
- No long-lived AWS keys; local CLI uses IAM Identity Center SSO.
- Gradle wrapper is `distributionSha256Sum`-pinned.
