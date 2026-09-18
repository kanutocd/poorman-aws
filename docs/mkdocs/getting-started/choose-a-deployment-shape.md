# Choose a deployment shape

Choose the smallest supported shape that matches the application. The backend
and frontend are independent: a consumer can deploy either one without
creating resources for the other.

## Backend and frontend

Use the backend OpenTofu stack for the public API. Call the reusable frontend
workflows for the consumer-owned SPA, CloudFront distribution, S3 assets,
certificate, and frontend DNS alias.

Set `API_BASE_URL` only when the frontend calls the deployed API. It is a
non-secret configuration handoff, not a provisioning dependency.

## Backend only

Use the backend stack, Packer profile, backend release workflows, and lifecycle
utilities. Choose this shape when the application exposes an API or background
service but has no frontend managed by this repository.

## Frontend only

Use the reusable frontend deployment and rollback workflows without creating
the backend stack. Omit `API_BASE_URL` when the frontend has no API dependency
or calls an API managed elsewhere. The frontend workflow does not assume a
Compose file or a particular hosting provider.
