# Recover production

This runbook defines the production recovery contract for the single-host
backend. It is an operator procedure, not an automated pull-request test. Do
not run restore or deletion actions against production without the required
AWS account, change approval, and environment protections.

The baseline recovery path replaces the disposable host root and reattaches a
restored copy of the retained data volume. It does not make the single host
multi-AZ or eliminate the need for an operator-led rehearsal.

## Recovery objectives and scope

- Recovery point objective (RPO): 24 hours.
- Recovery time objective (RTO): 4 hours.
- Backup scope: the retained production data EBS volume.
- Backup schedule: daily recovery points retained for 7 days and weekly
  recovery points retained for 28 days.
- Restore rehearsal: quarterly for production.

The data EBS volume is the durable host boundary. The host bootstrap moves the
Docker data root beneath the mounted data volume, so application persistent
data and Docker named-volume state, including Caddy certificate state, are
covered by the production data-volume backup. The root EBS volume is
disposable and is not the recovery source.

Immutable release artifacts remain in the private, versioned S3 artifact
bucket. The current release can be restored independently by activating a
known-good release ID through the wrapper's rollback command or the generated
rollback workflow.

## Production restore procedure

Before starting, collect the approved AWS account, production environment
approval, latest backup inventory, retained volume identifier, EIP, and the
known-good immutable release ID.

1. Declare the incident, record the observed failure time, and select the
   latest recovery point that satisfies the 24-hour RPO.
2. Preserve the failed host and retained volume identifiers for evidence. Do
   not run OpenTofu destroy or change `retain_data_volume` in production.
3. Using the approved AWS Backup restore operation, restore the selected
   recovery point to an encrypted EBS volume in the configured Availability
   Zone. Record the recovery point ARN, restore job ID, volume ID, and times.
4. Attach the restored volume to the replacement host through the approved
   operator procedure. Verify the filesystem, expected data directories, mount
   ownership, and Docker data root before starting the application.
5. Rebuild or replace the disposable host root from the reviewed AMI and
   restore the required host configuration through the normal infrastructure
   workflow. Preserve the production EIP and DNS boundary.
6. Activate the known-good immutable release ID through the wrapper or the
   generated rollback workflow. Verify the manifest checksums, runtime
   parameter rendering, Compose health, Caddy certificate state, and public API
   smoke checks.
7. Record the time from incident declaration to healthy service. Escalate if
   the measured recovery exceeds the 4-hour RTO.

Emergency deletion or nuking of the production data volume is intentionally
outside this project. It may only be performed explicitly through the AWS CLI
or console under the operator's emergency change procedure. The project must
not add an automated path that removes the retained production volume.

## Release rollback procedure

For an application regression where the data volume is healthy, use the
wrapper with a previously published release ID:

```bash
bin/poorman-aws rollback --environment production \
  --release-id KNOWN_GOOD_RELEASE_ID \
  --apply --confirm ROLLBACK-PRODUCTION
```

The command dispatches the consumer rollback workflow. The host verifies the
immutable manifest and checksums, switches the `current` release atomically,
restarts Compose, and restores the previous release if health verification
fails. This rollback does not alter the data volume or backup schedule.

## Quarterly rehearsal evidence

For each production rehearsal, record:

- rehearsal date, operator, environment, and change/incident reference;
- selected recovery point and AWS Backup job identifiers;
- restored volume and replacement host identifiers;
- release ID activated and checksum verification result;
- runtime, Caddy, Compose, API, and DNS/HTTPS verification results;
- measured RPO/RTO and any corrective actions.

The rehearsal must use an isolated recovery target and must not overwrite the
active production volume. Findings must be resolved or explicitly accepted
before the next quarterly rehearsal.
