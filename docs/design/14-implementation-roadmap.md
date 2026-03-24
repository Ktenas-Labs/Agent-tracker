# Agent Tracker v2.0 - Implementation Roadmap

## Phase 1 - Foundation (Weeks 1-3)

- Scaffold backend and Flutter projects.
- Implement auth (Google OAuth), RBAC basics.
- Create DB schema + migrations.
- Build CRUD APIs for regions, bases, units, users.
- Build base UI shell and navigation.

## Phase 2 - Core CRM Workflows (Weeks 4-6)

- Contacts and conversation logs.
- Brief scheduling/edit/complete flows.
- Status engine and overdue indicators.
- Search/filter/sort across key screens.

## Phase 3 - Calendar + Maps Intelligence (Weeks 7-8)

- Calendar views and conflict detection.
- Map display and distance calculations.
- Weekend opportunity suggestion endpoint and UI.

## Phase 4 - Google Workspace Integrations (Weeks 9-11)

- Calendar, Gmail, Drive, Sheets, Docs, Tasks, Contacts integrations.
- Sync jobs, retries, integration health monitoring.

## Phase 5 - Reporting and Exports (Weeks 12-13)

- Role-based dashboards.
- Full report set and export pipeline.
- SQL and API performance tuning for analytics.

## Phase 6 - Hardening and Release (Weeks 14-16)

- Offline sync conflict handling polish.
- Security review and penetration checklist.
- Load testing and observability tuning.
- Release prep for web + iOS + Android.

## Testing Strategy by Phase

- Unit tests from phase 1 onward.
- Integration tests per domain phase.
- End-to-end regression suite before release.

## Definition of Done (MVP)

- All required screens and workflows are implemented.
- RBAC/scoping enforced server-side.
- Required reports and exports available.
- Google integrations functional in production.
- Seed import pipeline operational.
- Documentation complete and deployment repeatable.
