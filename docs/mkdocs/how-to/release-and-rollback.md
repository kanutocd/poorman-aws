# Release and rollback

Use the `bin/poorman-aws` wrapper to dispatch immutable release and rollback
workflows. The host verifies the release manifest and artifact checksums before
switching the `current` release symlink. Use a full commit SHA or release tag
for the infrastructure reference; do not use `main` for production.

For a release:

1. Build the application image in the consumer repository.
2. Create an immutable release identified by the consumer's commit or release
   identifier.
3. Upload the release and checksums to the private artifact bucket.
4. Preview the wrapper dispatch from the consumer repository:

   ```bash
   bin/poorman-aws release --environment staging --dry-run \
     --apply --confirm RELEASE-STAGING
   ```

5. Dispatch the reviewed release by removing `--dry-run`.
6. Verify Compose, Caddy, API, CORS, and WebSocket health.

For a rollback:

1. Select a previously published immutable release ID and verify its checksums.
2. Preview and then dispatch the wrapper rollback command:

   ```bash
   bin/poorman-aws rollback --environment staging \
     --release-id KNOWN_GOOD_RELEASE_ID \
     --dry-run --apply --confirm ROLLBACK-STAGING
   ```

3. Verify the API, CORS, WebSocket, and Compose health checks.
4. If activation health checks fail, keep the previous release active and
   investigate before retrying.

A release rollback does not alter the retained production data volume or backup
schedule. It also does not restore application data; use the [recovery
runbook](../recovery.md) for that operation.
