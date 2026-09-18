# Cost model

The default architecture trades managed availability features for predictable
fixed costs and simple operations. Review the cost consequences of each
environment separately; a stopped or destroyed non-production environment is
not the same as a production recovery strategy.

- one public EC2 host avoids a managed load balancer and NAT Gateway;
- one Availability Zone is intentional and reduces cross-zone complexity;
- the Internet Gateway provides outbound access without a NAT Gateway;
- the S3 gateway endpoint optimizes artifact traffic; and
- immutable release retention and production backup retention are bounded by
  explicit policies. Production data-volume backups are retained daily for
  seven days and weekly for 28 days.

Document and review the cost impact before adding a managed NAT Gateway, load
balancer, always-on staging resources, or additional backup retention. The
single-AZ design also has an availability trade-off: an Availability Zone
failure is outside the guarantees of this baseline.
