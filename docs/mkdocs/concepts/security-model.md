# Security model

The infrastructure is intentionally small, but its boundaries are explicit.
The model assumes a protected GitHub environment and an operator who reviews
infrastructure plans before applying them.

## Network access

The public security group exposes only TCP ports 80 and 443. The application
listener remains bound to host loopback behind Caddy. Docker-dependent services
use internal Compose reachability rather than public host ports.

## Administration

Use AWS Systems Manager Session Manager instead of inbound SSH. IMDSv2 tokens
are required and the metadata hop limit remains one.

## Secrets

Runtime values are stored in SSM Parameter Store as `SecureString` values by
default. Secret values must not appear in frontend assets, Git, plans, logs,
release manifests, or documentation examples.

## Workflows

AWS deployment workflows use OIDC and least-privilege permissions. Reusable
workflow actions are pinned to immutable references. Destructive operations
require explicit environment protection and confirmation, and production
destruction fails closed. Frontend workflows use a separate frontend role from
backend infrastructure and release roles.

## What this model does not provide

The baseline is not a substitute for application authorization, WAF rules,
multi-AZ failover, or a managed database security model. The consumer must
secure its application endpoints and any external dependencies it chooses to
run.
