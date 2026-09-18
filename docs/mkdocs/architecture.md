# Architecture

## Status and scope

This document describes the reusable architecture and its current
implementation boundary. Consumer-specific runtime services and application
configuration remain outside the infrastructure contract.

The design optimizes for a small, low-traffic production deployment with a
strong preference for predictable fixed costs and simple operations. It trades
multi-AZ availability, managed scaling, and managed ingress for a single public
EC2 host, an Internet Gateway, and explicit operational guardrails.

The architecture is a baseline, not a required application topology. Consumers
choose their Compose services and frontend hosting implementation while keeping
the public ingress, loopback listener, secret, and lifecycle boundaries below.

## System context

The application may have a public frontend hosted by consumer-selected static
hosting and an independent public API hostname routed to the backend EC2 host.
The frontend may use an optional non-secret `API_BASE_URL` build/runtime
variable to call the API, but frontend deployment does not require backend
infrastructure. The backend reaches consumer-selected external dependencies
over outbound Internet access. Any database, queue, cache, search, or other
dependent services are internal Compose services and are never published to
the Internet.

```mermaid
flowchart LR
    User[Browser user]
    FrontendDNS[Frontend DNS]
    FrontendHosting[Consumer-owned frontend hosting]
    APIDNS[Route 53 API A record]
    API[Public backend HTTPS edge]
    Dependencies[External dependencies]

    User --> FrontendDNS --> FrontendHosting
    User --> APIDNS --> API
    API --> Dependencies
```

## AWS network topology

The backend stack creates one VPC and one public subnet in one Availability
Zone. The subnet has a default route through the Internet Gateway. The S3
gateway endpoint keeps artifact traffic on AWS networking while the host still
has direct egress to configured dependencies, package mirrors, and DNS.

```mermaid
flowchart TB
    Internet((Internet))
    Route53[Route 53 public zone]
    IGW[Internet Gateway]

    subgraph Region[AWS deployment region]
      subgraph VPC[Environment VPC]
        RouteTable[Public route table\n0.0.0.0/0 -> IGW]
        S3Endpoint[S3 gateway endpoint]
        subgraph Subnet[Single public subnet\nOne Availability Zone]
          SG[Instance security group\nIngress: 80, 443\nEgress: all]
          EIP[Elastic IP]
          EC2[ARM64 EC2 host\nIMDSv2 required\nSSM managed]
          RootEBS[Encrypted root EBS\nDisposable]
          DataEBS[Encrypted data EBS\nLifecycle controlled]
          Edge[Consumer-supplied HTTP/HTTPS edge\n80/443]
          Backend[Consumer application service\nPrivate Compose network]
          Dependencies[Optional internal services\nConsumer-defined]
        end
      end
      Artifacts[Private versioned S3\nrelease artifacts]
      SSM[SSM Parameter Store\nRuntime parameters]
      KMS[AWS managed or customer KMS\nParameter/session encryption]
    end

    Route53 --> EIP
    Internet --> IGW
    IGW --> RouteTable
    RouteTable --> SG
    SG --> EIP --> EC2
    EC2 --- RootEBS
    EC2 --- DataEBS
    EC2 --> Edge
    Edge --> Backend
    Backend --> Dependencies
    RouteTable --> S3Endpoint --> Artifacts
    EC2 --> SSM
    SSM --> KMS
    Backend -->|Configured dependency egress| Internet
```

### Network invariants

- The security group exposes only 80 and 443.
- The edge proxy reaches the application through the private Compose network
  or a consumer-selected loopback listener; the application is not directly
  exposed on a public host port.
- Consumer-defined dependent services use Compose `expose`, not host-published
  ports.
- The Internet Gateway is required for outbound provider and tool access.
- The S3 endpoint is an optimization and does not replace Internet egress.
- Session Manager replaces inbound SSH for normal administration.

## Public request and data flow

### Browser to API

```mermaid
sequenceDiagram
    participant Browser
    participant DNS as Route 53
    participant EIP as Elastic IP
    participant Edge as HTTP/HTTPS edge
    participant App as Backend container
    participant Dependencies

    Browser->>DNS: Resolve api.<domain>
    DNS-->>Browser: EIP address
    Browser->>Edge: HTTPS request on 443
    Edge->>App: Reverse proxy to the private application listener
    App->>Dependencies: Read or call configured services
    Dependencies-->>App: Service response
    App-->>Edge: JSON or health response
    Edge-->>Browser: HTTPS response
```

The exact application endpoints belong to the consuming application. The
infrastructure contract is the TLS edge, loopback application listener, and
internal service reachability.

### Frontend and WebSocket flow

```mermaid
flowchart LR
    Browser[Browser SPA]
    FrontendHosting[Consumer-owned frontend hosting]
    APIHost[api.<domain>]
    Edge[HTTP/HTTPS edge]
    WebSocket[Optional WebSocket endpoint]
    App[Backend application]

    Browser -->|HTML, JS, CSS| FrontendHosting
    Browser -->|REST API| APIHost --> Edge --> App
    Browser -->|Optional WebSocket upgrade| APIHost --> Edge --> WebSocket --> App
```

Frontend hosting is a separate consumer concern. The consumer owns its
frontend hosting resources, DNS/TLS integration, and deployment command.
Backend IaC owns only the API-side DNS record and backend resources.
`API_BASE_URL` is an optional configuration handoff from frontend deployment to
the frontend application, not a DNS or provisioning dependency.

## Release and activation flow

Application source remains in the consuming repository. The infrastructure
repository supplies the host, artifact bucket, activation mechanism, and
verification utilities.

Consumers may call the repository's reusable workflows directly. The called
workflow checks out the selected infrastructure ref into the runner, receives
non-sensitive variables as typed input and sensitive values as named GitHub
secrets, then executes the same `bin/` script used by local operators.

```mermaid
flowchart TD
    Commit[Consumer repository commit]
    Workflow[GitHub Actions deployment workflow]
    OIDC[GitHub OIDC token]
    IAM[Scoped AWS IAM deployment role]
    Build[Build immutable application image]
    Manifest[Create checksummed release manifest]
    S3[Upload release to private S3]
    State[Read OpenTofu state for bucket and host]
    SSMCommand[SSM Run Command]
    Host[EC2 host]
    Activate[Activate release script]
    Runtime[Render SSM runtime parameters]
    Compose[Docker Compose restart]
    Health[API health, CORS, and WebSocket checks]

    Commit --> Workflow
    Workflow --> OIDC --> IAM
    Workflow --> Build --> Manifest --> S3
    Workflow --> State
    Workflow --> SSMCommand --> Host --> Activate
    Activate --> Runtime
    Activate --> Compose
    Compose --> Health
    S3 --> Activate
```

Release activation is intended to be immutable and rollback-friendly:

1. Build and upload an immutable release identified by commit ID.
2. Verify the manifest and every artifact checksum on the host.
3. Render runtime parameters from SSM into a protected temporary release file.
4. Switch the `current` release symlink atomically.
5. Restart the Compose systemd service.
6. Restore the previous release if activation health checks fail.

## Secret and runtime-configuration flow

Provider credentials and optional API authentication are not frontend data.
They are written by an administrator-side bootstrap operation into an
environment-specific SSM path and read only by the EC2 instance role.

```mermaid
flowchart LR
    Operator[Privileged operator]
    EnvFile[Private local environment file]
    Bootstrap[Parameter bootstrap script]
    SSM[SSM SecureString parameters]
    KMS[KMS encryption]
    Role[EC2 instance IAM role]
    Renderer[Runtime environment renderer]
    Compose[Docker Compose environment]
    Backend[Backend process]
    Frontend[Public frontend assets]
    Logs[Logs and telemetry]

    Operator --> EnvFile --> Bootstrap --> SSM
    SSM --- KMS
    Role --> SSM
    Role --> Renderer --> Compose --> Backend
    Frontend -. never receives provider secrets .-> Backend
    Backend --> Logs
```

### Secret-handling rules

- Never place provider credentials in frontend build variables.
- Never print SSM values while bootstrapping or diagnosing a host.
- Only report presence, absence, or a non-sensitive status code during checks.
- Keep runtime files mode `0600` and owned by the host runtime account or root
  according to the activation contract.
- Treat logs, release manifests, plan files, and CI artifacts as potentially
  public unless access is explicitly restricted.

## Administrative access flow

```mermaid
sequenceDiagram
    participant Operator
    participant AWS as AWS CLI
    participant SSM as Systems Manager
    participant Host as EC2 host
    participant Docker

    Operator->>AWS: aws ssm start-session --target INSTANCE_ID
    AWS->>SSM: Authenticate and open encrypted session
    SSM->>Host: Start ssm-user session
    Host-->>Operator: Shell without inbound SSH
    Operator->>Docker: Inspect services as authorized host user
```

The EC2 security group does not need an SSH ingress rule. Session encryption
uses the configured SSM/KMS policy where a customer-managed key is selected.

## Lifecycle and cost model

```mermaid
stateDiagram-v2
    [*] --> Running
    Running --> Stopped: STOP non-production
    Stopped --> Running: Reapply or start instance
    Running --> Replaced: AMI or immutable host change
    Replaced --> Running
    Running --> Destroyed: DESTROY non-production
    Destroyed --> [*]
    Running --> Nuked: NUKE non-production
    Nuked --> [*]

    note right of Stopped
      STOP preserves the instance,
      EBS volumes, and EIP.
    end note

    note right of Destroyed
      DESTROY removes cost-bearing
      backend resources only.
    end note

    note right of Nuked
      NUKE removes the complete
      selected application environment.
    end note
```

Production destruction is intentionally guarded. Non-production retention
flags control the EIP and data volume lifecycle; the root volume remains
disposable. The public project must keep these policies explicit rather than
silently choosing retention defaults.

## Extraction boundary

The following current files are the main implementation surfaces:

- `backend/main.tf` composes networking, artifacts, compute, and DNS/TLS.
- `backend/modules/networking` owns the VPC and public subnet shape.
- `backend/modules/compute` owns EC2, EBS, EIP, IAM, IMDSv2, and bootstrap.
- `backend/modules/deployment-artifacts` owns private release storage.
- `backend/modules/dns-tls` owns the backend API Route 53 record only.
- `backend/packer` owns the host base image.
- `bin/` owns administrator and release operations.
- `.github/workflows/quality.yml` owns repository quality checks.
- The remaining `.github/workflows/*.yml` files provide reusable infrastructure
  delivery entry points for consumer repositories.

Frontend consumers separately own their concrete frontend hosting resources,
DNS/TLS integration, and deployment commands. This repository provides
reusable frontend delivery workflows without requiring a specific hosting
provider, frontend framework, domain name, or resource layout. A shared DNS
foundation may own the hosted zone and registrar delegation; neither
application stack should recreate a shared zone.

Application identity, hostnames, tags, SSM paths, Compose services, release
manifest shape, and GitHub OIDC policy scope are parameterized at the reusable
boundary. Do not solve this boundary with blind global string replacement;
preserve the diagrammed contracts and add consumer examples for each supported
shape.
