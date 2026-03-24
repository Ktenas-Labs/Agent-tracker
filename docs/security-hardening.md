# Security Hardening Checklist (OWASP-Aligned)

## Implemented in this pass

- Added API security middleware:
  - CORS allowlist (`ALLOWED_ORIGINS`)
  - Trusted host validation (`ALLOWED_HOSTS`)
  - Security headers: `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cache-Control`
- Hardened JWT claims/validation:
  - Added `iss`, `aud`, `iat`, `jti`, token `type`
  - Enforced audience/issuer during decode
- Restricted auth attack surface:
  - `mock-login` can be disabled via `ALLOW_MOCK_AUTH=false`
  - OAuth callback requires `state`
  - OAuth callback now fetches Google user info and rejects missing email
  - Token exchange errors no longer echo raw upstream response bodies
- Enforced authz on API endpoints:
  - Core/operations/integration/report routes now require authenticated roles
  - Admin/manager-only restrictions for higher-risk reporting and export routes
  - Removed unsafe pseudo-scoping fallback in `units/my`
- Added request validation hardening:
  - Length and minimum constraints on key schema fields
  - Coordinate and radius guardrails in map endpoints
- Added API abuse protection:
  - In-memory rate limit middleware with configurable request/window thresholds
- Added assignment-based row-level scoping:
  - New `unit_agent_assignments` model
  - `/units` now scopes agents to assigned units
  - New admin/manager endpoint `/admin/unit-assignments` for secure assignment mapping
- Production-safe startup defaults:
  - `CREATE_TABLES_ON_STARTUP=false` in env template (migrations-first behavior)

## Required before production

- Set `ALLOW_MOCK_AUTH=false`
- Keep `CREATE_TABLES_ON_STARTUP=false` and run Alembic migrations only
- Use a strong random JWT secret from a secret manager
- Restrict CORS/hosts to production domains only
- Encrypt Google refresh tokens at rest with KMS-backed key management
- Add persistent/distributed rate limiting (Redis or gateway-based) for multi-instance deployments
- Write-time enforcement for agents:
  - `POST /contacts`, `/conversations`, `/briefs` require assignment to `reserve_unit_id`
  - Agents cannot set `agent_id` / `assigned_agent_id` to another user
  - Brief creation validates `reserve_unit` / `base` / `region` chain matches the database (anti-IDOR)
- Add structured security/audit logging for auth and data exports
