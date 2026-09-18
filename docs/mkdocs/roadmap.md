# Roadmap and deferred wrapper work

This page records intentionally deferred work so the consumer experience can
continue to improve without losing the original goal: a small application
should be able to consume poorman-aws through pinned, independently usable
entry points.

The two setup scripts are already standalone consumption surfaces. They can be
run from a clone or fetched individually from a release tag or full commit
SHA:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/bootstrap-github-oidc \
  | bash -s -- --help

curl -fsSL \
  https://raw.githubusercontent.com/kanutocd/poorman-aws/refs/tags/v0.1.0/bin/sync-github-environment \
  | bash -s -- --help
```

## Direct bootstrap adapters

The wrapper should eventually expose explicit, strongly confirmed convenience
adapters for the two one-time setup operations that currently use separate
scripts:

- `bootstrap aws-oidc`, backed by `bin/bootstrap-github-oidc`;
- `github environment sync`, backed by `bin/sync-github-environment`.

The AWS adapter must remain visibly separate from ordinary deployment because
it requires account-level administrator access and changes IAM trust and
permissions. It must support dry-run policy review, immutable source refs,
explicit confirmation, and clear warnings before applying changes.

The GitHub adapter is a smaller gap. It must preserve stdin-based secret
handling, avoid printing secret values, require repository-environment
administration permission, and provide a dry-run before `--apply`.

For piped wrapper use, both adapters need a safe way to resolve the matching
immutable poorman-aws source ref. The implementation should either embed the
shared adapter logic in the wrapper or fetch the pinned script explicitly; it
must not silently fetch `main`.

Until these adapters exist, use the documented scripts directly during the
one-time setup phase. Repeatable planning, deployment, release, rollback,
smoke testing, and non-production teardown are already available through
`bin/poorman-aws`.
