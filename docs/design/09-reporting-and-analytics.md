# Agent Tracker v2.0 - Reporting and Analytics

## KPI Dashboards

### Agent
- Assigned units
- Upcoming briefs (7/30 day)
- Overdue follow-ups
- Brief completion rate
- Attendance totals

### Manager
- Team briefs scheduled/completed
- Team overdue follow-ups
- Stale units by agent
- Average attendance by agent

### Admin
- Global unit health by status
- Region/base coverage
- Integration sync health
- Export usage and audit events

## Required Reports

1. Units by region
2. Units by base
3. Units by status
4. Uncontacted units
5. Overdue follow-ups
6. Units not briefed in last 6 months
7. Agent activity counts
8. Briefs scheduled/completed per agent
9. Attendance totals/averages per agent
10. Canceled/rescheduled counts
11. Upcoming weekend opportunities

## Example SQL Snippets

```sql
-- Units by status
SELECT status, COUNT(*) AS unit_count
FROM reserve_units
GROUP BY status
ORDER BY unit_count DESC;

-- Overdue follow-ups
SELECT cl.id, ru.name AS unit_name, cl.follow_up_due_at, u.display_name AS agent
FROM conversation_logs cl
JOIN reserve_units ru ON ru.id = cl.reserve_unit_id
JOIN users u ON u.id = cl.agent_user_id
WHERE cl.follow_up_due_at < NOW()
ORDER BY cl.follow_up_due_at ASC;

-- Not briefed in last 6 months
SELECT ru.id, ru.name, MAX(b.completed_at) AS last_completed_brief
FROM reserve_units ru
LEFT JOIN briefs b ON b.reserve_unit_id = ru.id AND b.status = 'completed'
GROUP BY ru.id, ru.name
HAVING COALESCE(MAX(b.completed_at), TIMESTAMPTZ '1900-01-01') < NOW() - INTERVAL '180 days';
```

## Export Specifications

- CSV: UTF-8, comma-delimited, ISO datetime.
- Google Sheets export: append or replace tab mode.
- PDF summary: optional manager/admin report packets.

## Filtering Dimensions

- Date range
- Region/base/agent
- Unit status
- Brief status
- Communication channel
