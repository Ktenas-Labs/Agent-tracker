# Agent Tracker v2.0 - API Design

Base URL: `/api/v1`

## Standards

- Auth: `Authorization: Bearer <jwt>`
- Pagination: `page`, `pageSize` (default 25, max 200)
- Sorting: `sortBy`, `sortDir`
- Filtering: `filter[field]=value`
- Search: `q`

## Error Shape

```json
{
  "error": {
    "code": "validation_error",
    "message": "Invalid scheduled_at",
    "details": [{"field":"scheduled_at","issue":"must be future date"}],
    "traceId": "req-123"
  }
}
```

## Auth Endpoints

- `POST /auth/google/login`
- `GET /auth/google/callback`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/me`

## Core Resource Endpoints

- Regions: `GET/POST /regions`, `GET/PATCH/DELETE /regions/{id}`
- Bases: `GET/POST /bases`, `GET/PATCH/DELETE /bases/{id}`
- Units: `GET/POST /units`, `GET/PATCH/DELETE /units/{id}`
- Contacts: `GET/POST /contacts`, `GET/PATCH/DELETE /contacts/{id}`
- Conversations: `GET/POST /conversations`, `GET/PATCH/DELETE /conversations/{id}`
- Briefs: `GET/POST /briefs`, `GET/PATCH/DELETE /briefs/{id}`
- Brief attendance: `PUT /briefs/{id}/attendance`
- Users: `GET/POST /users`, `GET/PATCH /users/{id}`

## Reporting Endpoints

- `GET /reports/dashboard?roleView=agent|manager|admin`
- `GET /reports/units-by-region`
- `GET /reports/units-by-base`
- `GET /reports/units-by-status`
- `GET /reports/uncontacted-units`
- `GET /reports/overdue-followups`
- `GET /reports/not-briefed-6-months`
- `GET /reports/agent-activity`
- `GET /reports/briefs-by-agent`
- `GET /reports/attendance-by-agent`
- `GET /reports/canceled-rescheduled`
- `GET /reports/upcoming-weekend-opportunities`
- `POST /reports/export` (CSV, Sheets)

## Maps and Calendar

- `GET /maps/bases?regionId=&radiusMiles=&lat=&lng=`
- `GET /maps/distances?baseIds=...`
- `GET /maps/weekend-opportunities?maxMiles=20`
- `GET /calendar/events`
- `POST /calendar/briefs/{briefId}/sync`

## Google Integrations

- `GET /google/scopes`
- `POST /google/gmail/send-follow-up`
- `POST /google/drive/upload-material`
- `POST /google/sheets/export`
- `POST /google/docs/generate-brief-report`
- `POST /google/calendar/sync`
- `POST /google/tasks/create-follow-up`
- `POST /google/contacts/sync`

## Example DTOs

### Create Brief Request
```json
{
  "reserveUnitId":"uuid",
  "assignedAgentId":"uuid",
  "scheduledAt":"2026-05-11T14:00:00Z",
  "location":"Fort Example Building A",
  "estimatedEligibleLives":120,
  "notes":"Initial command brief"
}
```

### Brief Response
```json
{
  "id":"uuid",
  "status":"scheduled",
  "regionId":"uuid",
  "baseId":"uuid",
  "reserveUnitId":"uuid",
  "assignedAgentId":"uuid",
  "scheduledAt":"2026-05-11T14:00:00Z",
  "completedAt":null
}
```

## Authorization Rules (high-level)

- Admin: full access.
- Manager: scoped to managed regions/bases/units and subordinate agents.
- Agent: assigned territories and own records only.
