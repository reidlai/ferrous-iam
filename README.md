# ferrous-iam

[← Back to FerrousCX Root Architecture](https://github.com/reidlai/ferrous-cx)

[![Component Type: Identity & Access Management](https://img.shields.io/badge/component-IAM%20%26%20Auth-blue.svg)](https://github.com/reidlai/ferrous-cx)
[![License: MPL-2.0 / MIT](https://img.shields.io/badge/license-MPL--2.0%20%2F%20MIT-green.svg)](LICENSE)
[![DevSecOps CI: Tier 2](https://img.shields.io/badge/DevSecOps%20CI-Tier%202%20Passing-brightgreen.svg)](.github/workflows/devsecops-infra-ci.yml)
[![Container Security: Trivy Passing](https://img.shields.io/badge/Trivy-0%20High%2FCritical-brightgreen.svg)](#container-security--devsecops-tier-2-gate)
[![Target: Kanidm Rust IdP](https://img.shields.io/badge/engine-Kanidm%20(Pure%20Rust)-orange.svg)](#system-architecture)

**`ferrous-iam`** is the dedicated Authentication and Authorization (Identity & Access Management) submodule of the **FerrousCX** enterprise customer experience platform. Built on **Kanidm**—a pure-Rust, memory-safe identity management engine—it provides an enterprise-grade OpenID Connect (OIDC) and OAuth2 identity provider (IdP) with zero JVM and zero Python dependencies.

This submodule encapsulates the container image, configuration manifests, TLS certificate orchestration, and automated user/client provisioning for the FerrousCX stack.

---

## 🏛️ System Architecture

```mermaid
flowchart TD
    subgraph Clients ["Clients"]
        Frontend["ferrous-frontend<br/>(Svelte 5 / OIDC PKCE)"]
        CLI["API & Agent Services<br/>(OAuth2 M2M Tokens)"]
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

To ensure friction-free local evaluation while strictly maintaining DevSecOps hygiene (preventing committed credentials in Git), the submodule provisions three demo personas whose credentials are decoupled and injected via environment variables (`.env` file):

| Username | Role | Credential Source (Env Var) | Permissions & Scope |
| :--- | :--- | :--- | :--- |
| **`carlos.support`** | `customer_specialist` | `$CARLOS_SUPPORT_PASSWORD` | Access order resolution canvas, search reviews via vector search, request courtesy credits up to $15.00 via HITL proposal cards. |
| **`operations.lead`** | `operations_manager` | `$OPS_LEAD_PASSWORD` | Review high-priority dispute queues, approve courtesy credits up to $20.00 maximum, manage carrier SLAs and operational metrics. |
| **`admin.sec`** | `system_admin` | `$ADMIN_SEC_PASSWORD` | Manage platform governance, Kanidm security policies, token introspection, and system-level IAM configurations. |

---

## 🤖 Machine-to-Machine (M2M) Service Accounts

In addition to interactive user personas, `ferrous-iam` provisions the **residual machine accounts** that remain after the data platform moved to its own native authentication: two OAuth2 Client Credentials service accounts for the first-party services that call each other. The data platform (Apache Iggy, Arroyo, delta-rs) uses its own native credentials and is not a Kanidm client, and `stream-replay-rs` is a generic tool with no identity-provider dependency.

| Service Account | Display Name | Scopes | Permitted Actions |
| :--- | :--- | :--- | :--- |
| **`svc_ferrous_api`** | API Gateway Service | `api:gateway`, `command:dispatch`, `query:lakehouse`, `auth:introspect` | Accept client requests, dispatch commands, token exchange, query the Delta store through the embedded DataFusion |
| **`svc_ferrous_agent`** | Autonomous Agent Service | `agent:reasoning`, `vectordb:query`, `proposal:submit`, `lakehouse:read` | Vector database semantic queries, LLM reasoning, and HITL action proposal dispatch |

> [!NOTE]
> **Scopes are indicative.** The exact account and scope set is confirmed in the Story 1.3 rework.
>
> **Transition status.** `config/seed-m2m.json` and `scripts/provision-m2m.*` still create the six accounts of the former design (`svc_stream_replay`, `svc_ferrous_cqrses`, `svc_ferrous_streaming`, `svc_ferrous_lakehouse`, `svc_ferrous_api`, `svc_ferrous_agent`) until that story is delivered. Only `svc_ferrous_api` and `svc_ferrous_agent` are part of the target design.

---

## ⚡ Key Capabilities

1. **Pure-Rust IdP:** Powered by Kanidm, booting in **< 3 seconds** with an idle memory footprint of **< 60 MB RAM**.
2. **Sub-Millisecond JWT Validation:** `ferrous-api` caches Kanidm's JWKS public keys in-memory, validating JWT signatures locally in **< 0.5 ms** with zero network overhead per request.
3. **Automated Zero-Touch Provisioning:** Generates self-signed developer certificates, creates OIDC OAuth2 clients (`ferrous-frontend`, `ferrous-api`), and maps RBAC scopes without manual administrative console interaction.
4. **Machine-to-Machine (M2M) Tokens:** Provides client credentials grant tokens for the first-party services `ferrous-api` and `ferrous-agent`.
5. **Centralized Authority & Policy Authority (PAP & PDP):** Acts as the single source of truth for all enterprise authorities, scopes, roles, and authorization policies across FerrousCX. All policy rules and permissions are configured centrally in Kanidm; `ferrous-api` acts strictly as the Policy Enforcement Point (PEP).

---

## 📁 Repository Structure

```text
ferrous-iam/
├── .github/workflows/
│   └── devsecops-infra-ci.yml   # Tier 2 DevSecOps GitHub Actions workflow (Hadolint, Trivy, Gitleaks)
├── .env.example                  # Environment variable template for credentials & config
├── config/
│   ├── server.toml               # Kanidm daemon configuration
│   ├── seed-rbac.json            # Human personas and role declarations
│   ├── seed-m2m.json             # residual M2M service accounts & OAuth2 scopes (target: 2)
│   └── certs/                    # Local self-signed dev TLS certificates (git-ignored)
├── scripts/
│   ├── generate-dev-certs.sh     # OpenSSL dev TLS certificate generator (Bash)
│   ├── generate-dev-certs.ps1    # OpenSSL dev TLS certificate generator (PowerShell)
│   ├── get-admin-password.sh     # Admin credential recovery & helper (Bash)
│   ├── get-admin-password.ps1    # Admin credential recovery & helper (PowerShell)
│   ├── provision-human-rbac.sh   # Personas and group provisioner (Bash)
│   ├── provision-human-rbac.ps1  # Personas and group provisioner (PowerShell)
│   ├── provision-m2m.sh          # M2M service account provisioner (Bash)
│   └── provision-m2m.ps1         # M2M service account provisioner (PowerShell)
├── Dockerfile                    # Pinned Kanidm server container manifest
├── docker-compose.yml            # Local development runtime compose
└── README.md                     # Submodule documentation & architecture
```

---

## 🛠️ Developer Quickstart (< 3 minutes)

### Prerequisites

| OS Platform | Container Runtime | CLI / Scripting Tools | Cryptography |
| :--- | :--- | :--- | :--- |
| **Linux / macOS** | Docker & Docker Compose (`v2.20+`) | Bash (`4.0+`) | `openssl` (installed via system package manager) |
| **Windows** | Docker Desktop (with WSL 2 engine running) | PowerShell (`5.1` or `7+`) | `openssl.exe` (included with Git for Windows in `C:\Program Files\Git\usr\bin` or Winget) |

---

### Step 1: Initialize Local Environment Variables (`.env`)

In compliance with DevSecOps guidelines, plaintext credentials are never committed to Git. Instead, settings and secrets are decoupled into a local `.env` file that is git-ignored.

Copy the provided environment template to initialize your local `.env`:

```bash
# On Linux / macOS
cp .env.example .env
```

```powershell
# On Windows PowerShell
Copy-Item .env.example .env
```

*(Optional: You can inspect and adjust configuration variables in `.env` if desired for your local setup.)*

---

### Step 2: Generate Development TLS Certificates

Kanidm requires valid TLS certificates to boot. Generate self-signed certificates into `config/certs/`:

```bash
# On Linux / macOS
./scripts/generate-dev-certs.sh
```

```powershell
# On Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts/generate-dev-certs.ps1
```

---

### Step 3: Launch Kanidm Daemon

Ensure your Docker engine is running, then boot the container in the background:

```bash
# On Linux / macOS
docker compose up -d
```

```powershell
# On Windows PowerShell (ensure Docker Desktop shows "Engine running")
docker compose up -d

# Verify container is running and healthy:
docker compose ps
```

---

### Step 4: Provision Human Personas & M2M Service Accounts

Once the container is healthy, provision the 3 RBAC personas and the residual M2M service accounts (see the transition note above):

```bash
# On Linux / macOS
./scripts/provision-human-rbac.sh
./scripts/provision-m2m.sh
```

```powershell
# On Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts/provision-human-rbac.ps1
powershell -ExecutionPolicy Bypass -File scripts/provision-m2m.ps1
```

---

### Step 5: Kanidm Web UI & Administrative Console

Kanidm includes a built-in Web UI accessible directly from your browser:
* **Web UI URL:** `https://localhost:8443` (accept the local self-signed certificate warning)
* **Root Administrator Username:** `admin`

#### Initial Admin Login:
1. Kanidm's built-in root administrator username is **`admin`** (not `admin.sec`).
2. Run the credential recovery script to retrieve the admin one-time login token:
   ```bash
   # On Linux / macOS
   ./scripts/get-admin-password.sh
   ```
   ```powershell
   # On Windows PowerShell
   powershell -ExecutionPolicy Bypass -File scripts/get-admin-password.ps1
   ```
   *(This also saves the active password to the git-ignored `.secrets/admin_password.txt` file).*
3. Open `https://localhost:8443` in your browser.
4. Type **`admin`** in the Username box and click **Begin**.
5. Paste the generated password into the password prompt to log into the Kanidm Management Console.

* **Capabilities in UI:**
  - View, manage, and inspect user profiles and groups
  - Register MFA / FIDO2 / WebAuthn security keys
  - Manage OAuth2 / OIDC client integrations and active sessions

---

### Step 6: Verify Health and Daemon Status

Verify that the Kanidm daemon is healthy and responding over HTTPS:

```bash
# On Linux / macOS
curl -k -I https://localhost:8443/status
```

```powershell
# On Windows PowerShell (using curl.exe to avoid PowerShell's curl alias)
curl.exe -k -I https://localhost:8443/status

# Or using native PowerShell cmdlet (PowerShell 7+)
Invoke-WebRequest -SkipCertificateCheck -Uri https://localhost:8443/status
```

---

## 🔒 Container Security & DevSecOps (Tier 2 Gate)

Bound by **AD-13**, `ferrous-iam` implements strict container security standards enforced via `.github/workflows/devsecops-infra-ci.yml`:

* **Non-Root Execution:** The Kanidm service runs under the unprivileged `kanidm:kanidm` (UID 10001) user.
* **Pinned Base Images:** Built against cryptographically pinned official releases (`kanidm/server:1.11.2`).
* **Continuous Vulnerability Auditing:** Tested with `trivy` with a zero HIGH/CRITICAL vulnerability tolerance (`exit-code: 1`).
* **Linting:** Scanned with `hadolint` for Dockerfile best practices.
* **Secret Detection:** Scanned with `gitleaks` to prevent accidental credential leakage in repository history.
