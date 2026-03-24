# Agent Tracker v2.0 - Google Workspace Integration

## Integration Scope (MVP)

- OAuth 2.0 (Google Workspace)
- Gmail
- Drive
- Sheets
- Docs
- Calendar
- Tasks
- Maps
- Contacts

## OAuth and Scopes

Minimum scopes (finalized during security review):
- `openid`, `email`, `profile`
- `https://www.googleapis.com/auth/gmail.send`
- `https://www.googleapis.com/auth/drive.file`
- `https://www.googleapis.com/auth/spreadsheets`
- `https://www.googleapis.com/auth/documents`
- `https://www.googleapis.com/auth/calendar`
- `https://www.googleapis.com/auth/tasks`
- `https://www.googleapis.com/auth/contacts`

## Service-by-Service Behavior

### Gmail
- Send follow-up emails from conversation/brief screens.
- Store message metadata and thread ID back to CRM timeline.

### Drive
- Upload/share briefing materials.
- Store Drive file IDs linked to brief records.

### Sheets
- Push report outputs to target spreadsheet.
- Optional pull import sheets for admin-managed data ingestion.

### Docs
- Generate brief summary documents from templates.
- Save doc link back to brief and optionally email via Gmail.

### Calendar
- Sync brief events two-way.
- Pull unit training weekends from linked calendars where available.

### Tasks
- Create follow-up tasks from conversation logs.
- Sync completion back to local follow-up state.

### Maps
- Geocoding and distance calculations.
- Deep links for navigation.

### Contacts
- Import selected contacts to CRM.
- Sync updates for mapped fields with conflict logs.

## Sync Strategy

- Outbound writes: near-real-time via async jobs.
- Inbound updates: periodic poll + webhook where supported.
- Conflict policy:
  - app-owned fields override by default
  - user-contact fields prompt on conflict for admins/managers

## Operational Considerations

- Token refresh handling and revocation detection.
- Quota monitoring and backoff.
- Per-user integration health dashboard.
