# Agent Tracker v2.0 - Product Requirements

## 1) Personas and Goals

### Admin
- Manage users, roles, regions, bases, units, contacts, briefs, and global settings.
- View all reports across all territories.
- Control integration settings and import/export operations.

### Manager
- Assign agents to regions/bases/units.
- Track team activity, stale accounts, overdue follow-ups, and unit health.
- Review performance and intervention opportunities.

### Agent
- Work assigned territory only.
- Log conversations and outcomes quickly in field conditions.
- Schedule and complete briefs, capture attendance and notes.

## 2) Permissions Matrix (MVP)

| Capability | Admin | Manager | Agent |
|---|---|---|---|
| Manage users/roles | Yes | No | No |
| Assign territories | Yes | Yes | No |
| View all regions/bases/units | Yes | Scoped | Assigned only |
| Manage contacts/conversations | Yes | Scoped | Assigned only |
| Schedule/edit briefs | Yes | Scoped | Assigned only |
| Enter attendance/outcomes | Yes | Scoped | Assigned only |
| View all reports | Yes | Team-scoped | Self-scoped |
| Configure integrations | Yes | No | No |

## 3) Functional Requirements

### Territory Management
- CRUD for regions, bases, reserve units.
- Base belongs to one region.
- Reserve unit belongs to one base.
- Agent assignment at region, base, and unit levels.
- Summary counts on each hierarchy level.

### Contact and Conversation Management
- Multiple contacts per unit with role metadata.
- Conversation logs require: date/time, agent, contact person, role, channel, summary, next step, follow-up due date.
- Quick-add conversation from unit detail and dashboard.
- Overdue follow-up indicators and queues.

### Brief Lifecycle
- Brief statuses: `scheduled`, `completed`, `canceled`, `rescheduled`.
- Required fields include reserve unit, assigned agent, scheduled date/time.
- Completion requires attendance and outcome fields.
- Reschedule requires reason.
- Maintain immutable history for audit.

### Scheduling and Calendar
- Monthly/weekly calendar view for briefs and training windows.
- Highlight overdue contact and overdue brief conditions.
- Conflict detection for double-booked agents.
- Filter by region/base/agent/status/date.

### Maps and Route Intelligence
- Map of bases with status markers.
- Distance calculations between bases.
- Weekend opportunity suggestions:
  - same/similar training windows
  - bases within configurable threshold (default 20 miles)
- Direction handoff to Google Maps.

### Search/Sort/Filter
- Global search across units, contacts, bases.
- Per-screen filter chips and saved filter sets.
- Sort by latest activity, overdue date, status, distance, attendance metrics.

### Reporting and Exports
- Units by region/base/status.
- Uncontacted units.
- Overdue follow-ups.
- Units not briefed in last 6 months.
- Agent activity counts.
- Briefs scheduled/completed per agent.
- Attendance totals/averages per agent.
- Canceled/rescheduled counts.
- Upcoming weekend opportunities.
- Export to CSV and Google Sheets.

## 4) Non-Functional Requirements

- Data-dense, business-first UI optimized for rapid entry.
- Typical list interactions must remain responsive under 10k+ records.
- Offline-first mobile behavior with sync queues and conflict handling.
- Auditability for major record changes.
- Secure OAuth-based sign-in with RBAC enforcement on every API.

## 5) Business Rules

1. Unit status options:
   - `Uncontacted`
   - `Contacted`
   - `Scheduling`
   - `Scheduled`
   - `Briefed`
   - `Follow-Up Needed`
   - `Inactive`
2. Overdue follow-up: follow-up due date < now and not resolved.
3. Not briefed in 6 months: no completed brief within trailing 180 days.
4. Manager visibility includes direct and inherited assignments.
5. Admin has global visibility and override privileges.

## 6) Acceptance Criteria (Representative)

- Agent can create a conversation log from unit detail in <= 3 taps after opening quick-add.
- Manager dashboard shows stale/overdue counts consistent with report endpoints.
- Calendar reflects newly scheduled brief within sync SLA (<= 60 seconds online).
- Route suggestion endpoint returns grouped opportunities by weekend + distance.
- Exported report totals match on-screen totals for same filter/time range.

## 7) Out of Scope (MVP)

- Predictive recommendations/AI scoring.
- Real-time collaborative editing.
- Multi-company tenancy.
