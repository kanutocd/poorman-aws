# Frontend workflows

Frontend workflows are hosting-provider neutral. The consumer owns its
frontend source, hosting resources, build system, deploy command, domains, and
frontend IAM role. `poorman-aws` owns the workflow orchestration, immutable
checkout, output scanning, and optional live smoke checks.

## Frontend deployment

Workflow: `.github/workflows/deploy-frontend.yml`

Required inputs:

| Input | Meaning |
| --- | --- |
| `infrastructure_repository` | Repository containing `poorman-aws`. |
| `infrastructure_ref` | Immutable infrastructure tag or SHA. |
| `application_name` | Consumer application identity. |
| `environment` | Frontend deployment environment. |
| `aws_region` | Region used by the consumer deploy command. |
| `build_command` | Consumer-owned build command. |
| `deploy_command` | Consumer-owned deploy command. |
| `aws_role_arn` secret | Frontend-only IAM role. |

`frontend_directory` defaults to `frontend`. Optional inputs include
`output_entrypoint`, `frontend_url`, `api_url`, `frontend_origin`,
`api_base_url`, and `frontend_certificate_arn`. The optional
`application_api_token` secret is used only by acceptance checks.

Commands run inside `frontend_directory`. The workflow checks the configured
output entrypoint when provided and scans emitted assets for common credential
patterns. If both `frontend_url` and `api_url` are present, it runs the shared
frontend smoke checks.

```yaml
jobs:
  frontend:
    uses: kanutocd/poorman-aws/.github/workflows/deploy-frontend.yml@v0.1.0
    with:
      infrastructure_repository: kanutocd/poorman-aws
      infrastructure_ref: v0.1.0
      application_name: example-app
      environment: staging
      aws_region: ap-southeast-1
      frontend_directory: frontend
      build_command: npm run build
      deploy_command: npm run deploy
      output_entrypoint: dist/index.html
      frontend_url: https://app.example.test
      api_url: https://api.example.test
      frontend_origin: https://app.example.test
    secrets:
      aws_role_arn: ${{ secrets.AWS_FRONTEND_ROLE_ARN }}
      application_api_token: ${{ secrets.FRONTEND_API_TOKEN }}
```

## Frontend rollback

Workflow: `.github/workflows/rollback-frontend.yml`

This workflow has the same build, deploy, URL, and role contract as frontend
deployment, plus required `consumer_ref`. It checks out that immutable consumer
revision, builds it, scans the output, redeploys it, and retries acceptance
checks while the hosting provider propagates the change.

Use a known-good consumer SHA or release tag. Do not use `main` or rely on the
caller’s current branch for rollback behavior.

## Frontend lifecycle

Workflow: `.github/workflows/kill-frontend-non-production.yml`

This workflow supports only `DESTROY` and `NUKE` for non-production frontend
resources. It requires `infrastructure_repository`, `infrastructure_ref`,
`application_name`, `environment`, `action`, `confirmation`, `aws_region`,
`frontend_hostname`, and an immutable `consumer_ref`. The optional
`frontend_directory` defaults to `frontend`; `frontend_remove_command` is
required for an applied `NUKE` operation.

The required `aws_role_arn` secret must be a frontend-only role. Production is
rejected before the removal command can run. Use the wrapper's
`frontend lifecycle` adapter to enforce the same guard before dispatch.

## Frontend safety rules

- Keep backend and frontend IAM roles separate.
- Treat build and deploy commands as consumer-owned, reviewed configuration.
- Never pass credentials through `with` inputs or frontend build variables.
- Never emit provider credentials into frontend assets.
- Use immutable infrastructure and consumer refs for production and rollback.
- Treat lifecycle operations as non-production only.
