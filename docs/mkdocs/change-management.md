# Infrastructure change management

Changes to IAM, lifecycle protection, retention, recovery, or workflow action
references require focused review because they can affect access boundaries,
data durability, cost, or the ability to recover a production service.

## Required review checklist

1. Identify the affected environment and whether production is in scope.
2. Update the relevant plan-only or offline contract test before changing
   behavior.
3. For IAM changes, list every action, resource ARN, condition key, and
   affected workflow. Reject wildcard actions and unrelated resource access.
4. For lifecycle changes, verify replacement, retention, `prevent_destroy`,
   and production fail-closed behavior.
5. For retention or recovery changes, record the RPO/RTO impact, AWS cost
   impact, restore source, and rehearsal evidence required.
6. For workflow action changes, pin the exact commit SHA and run the immutable
   action-reference check.
7. Run `bash bin/quality`, workflow validation, and the narrow affected tests.
8. For production-impacting changes, require a reviewed plan and protected
   environment approval before apply. Never include credentials, plans, state,
   provider responses, or secret values in the change.

## Rollback expectations

Every change must identify its rollback path before merge. Application
regressions use an immutable release rollback. Data recovery uses the
production recovery runbook and retained data-volume backups. IAM or workflow
changes are rolled back through a reviewed commit and a fresh quality run;
they must not be repaired by weakening production lifecycle protections.
