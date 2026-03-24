# Agent Tracker v2.0 - Authentication and RBAC

## Authentication

- Google OAuth 2.0 authorization code flow.
- Backend exchanges code for tokens; stores encrypted refresh token.
- Access JWT lifetime: 15 minutes.
- Refresh token lifetime: 30 days (rotating).

## JWT Claims

- `sub` user UUID
- `email`
- `role` (`admin|manager|agent`)
- `scope` list of API scopes
- `exp`, `iat`, `iss`, `aud`

## RBAC Matrix

| Resource | Admin | Manager | Agent |
|---|---|---|---|
| Users | CRUD | Read team | Read self |
| Regions/Bases/Units | CRUD | Read + assign scoped | Read assigned |
| Contacts | CRUD | CRUD scoped | CRUD assigned |
| Conversations | CRUD | CRUD scoped | CRUD assigned |
| Briefs | CRUD | CRUD scoped | CRUD assigned |
| Reports | All | Team scoped | Self scoped |
| Integration settings | All | None | None |

## Data Scoping Rules

1. Agent access limited to units assigned directly or inherited by base/region assignment.
2. Manager access includes all assigned territories and subordinate agent records.
3. Admin bypasses territorial scope checks.

## Enforcement Pattern

- Route-level role guard.
- Service-layer scope checks with assignment joins.
- Query constraints always server-side (never trust client filtering).

## Invitation and Provisioning

- Admin invites via email.
- First login validates workspace domain allowlist.
- User created with default role `agent` unless explicit admin assignment.

## Security Controls

- TLS everywhere.
- CSRF protections on browser auth flows.
- Rate limiting on auth endpoints.
- Audit trail for role changes, assignment changes, and export actions.
