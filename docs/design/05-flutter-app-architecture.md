# Agent Tracker v2.0 - Flutter App Architecture

## Stack

- Flutter stable (3.x), Dart 3.x
- Riverpod for state management
- GoRouter for navigation
- Dio for networking
- Freezed + json_serializable for typed models
- Drift (mobile) + IndexedDB adapter (web cache)

## Module Layout

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    constants/
    errors/
    utils/
    widgets/
  domain/
    entities/
    enums/
    value_objects/
    repositories/
  data/
    datasources/
      local/
      remote/
    dto/
    mappers/
    repositories_impl/
  features/
    auth/
    dashboard/
    regions/
    bases/
    units/
    contacts/
    conversations/
    briefs/
    calendar/
    maps/
    reports/
    admin/
    settings/
  services/
    sync/
    google/
```

## State Management Pattern

- Feature-scoped providers for queries and commands.
- Immutable state classes per screen (`Loading`, `Ready`, `Error`).
- Use-case actions return domain results, not raw HTTP responses.

## Repository Contract Pattern

- Domain repository interfaces in `domain/repositories`.
- Implementations in `data/repositories_impl`.
- Local-first reads (if available), background remote refresh.
- Writes staged to local queue then synced.

## Offline and Sync

- Local operation queue table with retry metadata.
- Sync trigger:
  - app foreground
  - connectivity restored
  - manual refresh
- Conflict strategy:
  - safe merges for non-critical fields
  - explicit conflict prompt for critical event outcomes

## Navigation

- Top-level role-aware shell routes:
  - `/dashboard`
  - `/regions`
  - `/bases`
  - `/units`
  - `/calendar`
  - `/maps`
  - `/reports`
  - `/admin`
  - `/settings`

## Testing Strategy

- Unit tests: entities, use-cases, mappers.
- Widget tests: key forms and list/detail flows.
- Integration tests: login, brief lifecycle, sync behavior.
