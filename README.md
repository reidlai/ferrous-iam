# ferrous-iam

[← Back to FerrousCX Root Architecture](https://github.com/reidlai/ferrouscx-bmad)

[![Component Type: Identity & Access Management](https://img.shields.io/badge/component-IAM%20%26%20Auth-blue.svg)](https://github.com/reidlai/ferrouscx-bmad)
[![License: MPL-2.0 / MIT](https://img.shields.io/badge/license-MPL--2.0%20%2F%20MIT-green.svg)](LICENSE)
[![DevSecOps CI: Tier 2](https://img.shields.io/badge/DevSecOps%20CI-Tier%202%20Passing-brightgreen.svg)](.github/workflows/devsecops-infra-ci.yml)
[![Container Security: Trivy Passing](https://img.shields.io/badge/Trivy-0%20High%2FCritical-brightgreen.svg)](#container-security--devsecops)
[![Target: Kanidm Rust IdP](https://img.shields.io/badge/engine-Kanidm%20(Pure%20Rust)-orange.svg)](#system-architecture)

**`ferrous-iam`** is the dedicated Authentication and Authorization (Identity & Access Management) submodule of the **FerrousCX** enterprise customer experience platform. Built on **Kanidm**—a pure-Rust, memory-safe identity management engine—it provides an enterprise-grade OpenID Connect (OIDC) and OAuth2 identity provider (IdP) with zero JVM and zero Python dependencies.

This submodule encapsulates the container image, configuration manifests, TLS certificate orchestration, and automated user/client provisioning for the FerrousCX stack.

---

## 🏛️ System Architecture

```mermaid
flowchart TD
    subgraph Clients ["Clients"]
        Frontend["ferrous-frontend<br/>(Svelte 5 / OIDC PKCE)"]
        CLI["Automation & Replayer<br/>(OAuth2 M2M Tokens)"]
    end

    subgraph IAM ["ferrous-iam Submodule (Kanidm)"]
        Kanidm[("Kanidm Identity Server<br/>• Port 8443 (HTTPS / OIDC)<br/>• Port 3636 (LDAPS)")]
        Provisioner["Auto-Provisioning Engine<br/>• Generates Dev TLS Certs<br/>• Seeds OIDC Clients & RBAC Users"]
        Provisioner --> Kanidm
    end

    subgraph Services ["FerrousCX Services"]
        Gateway["ferrous-api<br/>(Axum Gateway & JWKS Validator)"]
        CQRS["ferrous-cqrses<br/>(Domain Invariant Enforcement)"]
    end

    Frontend -->|1. Authenticate via OIDC PKCE| Kanidm
    CLI -->|Client Credentials (M2M)| Kanidm
    Frontend -->|2. Dispatch API Requests + Bearer JWT| Gateway
    Gateway -.->|Cached JWKS Signature Check| Kanidm
    Gateway -->|3. Validated Persona Claims| CQRS
```

### Communication Protocols & Ports

| Component | Port | Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| **Kanidm HTTPS / OIDC** | `8443` | HTTPS / TLS 1.3 | OIDC Discovery (`/.well-known`), Authorization Code + PKCE, Token endpoints |
| **Kanidm LDAPS** | `3636` | LDAPS / TLS | Secure directory services and internal identity synchronization |

---

## 👥 Pre-Seeded Identities & RBAC Roles

To ensure friction-free local evaluation, the submodule automatically provisions three demo personas upon boot:

| Username | Default Password | Role | Permissions & Scope |
| :--- | :--- | :--- | :--- |
| **`carlos`** | `carlos_password` | `SupportSpecialist` | Access order resolution canvas, search reviews via Qdrant, request courtesy credits up to $15.00 via HITL proposal cards. |
| **`elena`** | `elena_password` | `Supervisor` | Review high-priority dispute queues, approve courtesy credits exceeding $15.00 (up to $20.00 maximum), review audit logs. |
| **`admin`** | `admin_password` | `PlatformAdmin` | Manage stream playback multipliers, trigger schema migrations in Arroyo, inspect Apache Iggy topics and partition offsets. |

---

## 🤖 Machine-to-Machine (M2M) Service Accounts

In addition to interactive user personas, `ferrous-iam` provisions dedicated OAuth2 Client Credentials service accounts to enforce least-privilege security between backend components:

| Service Account | Client ID | Scopes | Permitted Actions |
| :--- | :--- | :--- | :--- |
| **`svc_ferrous_api`** | `svc_api_gateway` | `api:gateway`, `events:publish`, `lakehouse:read` | Accept client requests, publish commands to Iggy, query Delta Lake via DataFusion |
| **`svc_ferrous_streaming`** | `svc_streaming_engine` | `stream:broker`, `stream:process`, `lakehouse:write` | Manage Iggy topics/partitions, Arroyo stream compute, 2PC Parquet commits |
| **`svc_ferrous_cqrses`** | `svc_cqrs_handler` | `cqrs:consume`, `cqrs:publish`, `lakehouse:write` | Consume commands from Iggy WAL, emit validated state projections to Arroyo |
| **`svc_ferrous_query`** | `svc_query_engine` | `lakehouse:read`, `query:vectorized` | Execute vectorized DataFusion SQL scans over Delta Lake Parquet tables |
| **`svc_ferrous_lakehouse`** | `svc_lakehouse_storage` | `storage:manage`, `storage:audit` | Delta Lake transaction log maintenance (`OPTIMIZE`, `VACUUM`), schema validation |
| **`svc_stream_replay`** | `svc_traffic_replayer` | `stream:inject` | Inject historical traffic payloads into Apache Iggy via Kafka 9092 gateway |

---

## ⚡ Key Capabilities

1. **Pure-Rust IdP:** Powered by Kanidm, booting in **< 3 seconds** with an idle memory footprint of **< 60 MB RAM**.
2. **Sub-Millisecond JWT Validation:** `ferrous-api` caches Kanidm's JWKS public keys in-memory, validating JWT signatures locally in **< 0.5 ms** with zero network overhead per request.
3. **Automated Zero-Touch Provisioning:** Generates self-signed developer certificates, creates OIDC OAuth2 clients (`ferrous-frontend`, `ferrous-api`), and maps RBAC scopes without manual administrative console interaction.
4. **Machine-to-Machine (M2M) Tokens:** Provides client credentials grant tokens for automated traffic injection scripts (`stream-replay-rs`) and CI pipelines.
5. **Centralized Authority & Policy Authority (PAP & PDP):** Acts as the single source of truth for all enterprise authorities, scopes, roles, and authorization policies across FerrousCX. All policy rules and permissions are configured centrally in Kanidm; `ferrous-api` acts strictly as the Policy Enforcement Point (PEP).

---

## 📁 Repository Structure

```text
ferrous-iam/
├── .github/workflows/
│   └── devsecops-infra-ci.yml   # Tier 2 DevSecOps GitHub Actions workflow
├── .pre-commit-config.yaml       # Universal shift-left pre-commit configuration
├── config/
│   ├── kanidm-server.toml        # Kanidm daemon configuration
│   └── certs/                    # Local self-signed dev TLS certificates
├── scripts/
│   ├── provision.sh              # Automated client, scope, and user seeding script
│   └── entrypoint.sh             # Container bootstrap and provisioning hook
├── Dockerfile                    # Pinned Kanidm server container manifest
└── README.md                     # Submodule documentation & architecture
```

---

## 🛠️ Developer Quickstart

### Prerequisites
* Docker & Docker Compose (`v2.20+`)
* OpenSSL (optional, if generating custom certificates outside Docker)

### 1. Launch via Unified Local Runtime (`ferrous-docker`)
The easiest way to run `ferrous-iam` is through the central Docker Compose environment:

```bash
cd ../ferrous-docker
docker compose up -d ferrous-iam
```

### 2. Standalone Build & Run
To run `ferrous-iam` in complete isolation:

```bash
# Build the container
docker build -t ferrous-iam:latest .

# Run with persistent volume for identity storage
docker run -d \
  --name ferrous-iam \
  -p 8443:8443 \
  -p 3636:3636 \
  -v kanidm_data:/data \
  ferrous-iam:latest

# Verify health and OIDC discovery
curl -k https://localhost:8443/oauth2/openid/ferrous-frontend/.well-known/openid-configuration
```

---

## 🔒 Container Security & DevSecOps (Tier 2 Gate)

Bound by **AD-13**, `ferrous-iam` implements strict container security standards:

* **Non-Root Execution:** The Kanidm service runs under the unprivileged `kanidm:kanidm` (UID 10001) user.
* **Pinned Base Images:** Built against cryptographically pinned official releases.
* **Continuous Vulnerability Auditing:** Tested with `trivy` with a zero HIGH/CRITICAL vulnerability tolerance.
* **Linting:** Scanned with `hadolint` for Dockerfile best practices.
