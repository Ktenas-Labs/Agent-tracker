# Agent Tracker v2.0 - Maps, Scheduling, and Routing

## Map Features

- Plot all bases with status-coded markers.
- Tap marker to open base summary and linked units.
- Radius search: 5/10/20/50 miles from selected base or current location.

## Distance Logic

- Primary method: Google Distance Matrix API.
- Fallback method: Haversine straight-line distance.
- Store cached pair distances in DB to reduce API spend.

## Calendar Features

- Month and week views.
- Layers:
  - scheduled briefs
  - completed briefs
  - training/drill weekends
  - overdue follow-up markers
- Conflict checks on create/update brief.

## Weekend Opportunity Algorithm (MVP)

1. Select date window and anchor base.
2. Retrieve bases within `maxMiles` (default 20).
3. Join reserve units with training windows in target dates.
4. Score each candidate:
   - distance score
   - unit priority score (overdue + uncontacted weight)
   - available-slot score
5. Group top combinations into multi-stop suggestions.

## Pseudocode

```text
candidates = nearbyBases(anchorBase, maxMiles)
units = unitsWithTrainingWeekends(candidates, dateRange)
for unit in units:
  score = w1*distanceWeight + w2*priorityWeight + w3*availabilityWeight
ranked = sortByScore(units)
return groupIntoWeekendRoutes(ranked, maxStops=3)
```

## API Contract

- `GET /maps/weekend-opportunities?anchorBaseId=&startDate=&endDate=&maxMiles=20`
- Response includes:
  - suggested stops
  - estimated total distance
  - units and statuses
  - recommended action notes
