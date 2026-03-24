# Agent Tracker v2.0 - Master Index

## Product Requirements Summary

Agent Tracker v2.0 is a production-grade field-sales operations and CRM platform for supplemental life insurance outreach across Army Reserve units. It supports three clients (Web, iOS, Android) from a shared Flutter codebase, backed by FastAPI and PostgreSQL on Google Cloud. The system enables territory assignment, reserve-unit relationship management, conversation logging, brief scheduling, attendance tracking, route planning, role-based access, and export-ready reporting, with full Google Workspace integration in MVP.

## Scope Snapshot

- **Users**: Admin, Manager, Agent
- **Hierarchy**: Region -> Base -> Reserve Unit
- **Primary workflows**: contact management, conversation logging, brief planning/execution, follow-up tracking
- **Core intelligence**: overdue/stale account detection, nearby-base suggestions, weekend opportunity detection
- **Reporting**: performance dashboards, operational health reports, exports to CSV and Google Sheets

## Assumptions

1. Organization uses Google Workspace and can approve required OAuth scopes.
2. Internet access is intermittent for field agents; mobile clients must work offline-first with eventual sync.
3. `docs/US Army_all_states_in_one.xlsx` is partial source data requiring transformation and validation before production import.
4. Region definitions are business-owned and can change over time without schema redesign.
5. Maps and distance calculations can use Google Maps Platform APIs in production.
6. Admin can manually override assignments and status when business exceptions occur.
7. U.S.-only operations for MVP (states table retained as reference dimension).

## Known MVP Limitations

- Route optimization is heuristic (distance + shared training windows), not full TSP optimization.
- Full bi-directional reconciliation for every Google service may be delayed per API quota/consent constraints.
- No advanced ML forecasting in MVP; analytics are deterministic SQL aggregations.
- No cross-tenant multi-company support in MVP.

## Future Enhancements

- Predictive lead scoring and briefing success probability.
- Territory balancing recommendations by agent capacity and travel burden.
- Automated email drafting with policy-safe AI templates.
- Voice-to-CRM logging for post-visit notes.
- Real-time collaboration (co-editing notes, live assignment board).
- Enterprise SSO expansion beyond Google Workspace.

## Documentation Map

1. [`01-product-requirements.md`](./01-product-requirements.md)
2. [`02-system-architecture.md`](./02-system-architecture.md)
3. [`03-data-model.md`](./03-data-model.md)
4. [`04-api-design.md`](./04-api-design.md)
5. [`05-flutter-app-architecture.md`](./05-flutter-app-architecture.md)
6. [`06-ui-ux-specification.md`](./06-ui-ux-specification.md)
7. [`07-google-workspace-integration.md`](./07-google-workspace-integration.md)
8. [`08-auth-and-rbac.md`](./08-auth-and-rbac.md)
9. [`09-reporting-and-analytics.md`](./09-reporting-and-analytics.md)
10. [`10-maps-scheduling-routing.md`](./10-maps-scheduling-routing.md)
11. [`11-seed-data-strategy.md`](./11-seed-data-strategy.md)
12. [`12-deployment-and-infrastructure.md`](./12-deployment-and-infrastructure.md)
13. [`13-project-structure.md`](./13-project-structure.md)
14. [`14-implementation-roadmap.md`](./14-implementation-roadmap.md)

## Glossary

- **Reserve Unit**: Core customer entity under a base where outreach and briefings occur.
- **Brief**: Sales briefing event planned or completed by an agent.
- **Training Weekend / Drill Weekend**: Unit training window used for scheduling opportunities.
- **Eligible Lives Reached**: Estimated number of personnel eligible for supplemental life product exposure during a brief.
- **Stale Account**: Unit with no meaningful engagement within configured threshold.
- **Overdue Follow-Up**: Any conversation or brief follow-up past due date.
- **PAX**: Attendance/personnel count for a briefing context.
- **SSLI/RGLI**: Program references used in reporting, workflows, and messaging.
