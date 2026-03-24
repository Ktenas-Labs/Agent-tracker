# Agent Tracker v2.0 - Project Structure

## Repository Layout

```text
army/
  docs/
    design/
  backend/
  frontend/
  scripts/
  infra/
```

## Backend (FastAPI)

```text
backend/
  app/
    api/v1/endpoints/
    core/
    models/
    schemas/
    services/
    repositories/
    integrations/google/
    tasks/
  alembic/
  tests/
  scripts/
  requirements.txt
  Dockerfile
```

## Frontend (Flutter)

```text
frontend/
  lib/
    app/
    core/
    domain/
    data/
    features/
    services/
  test/
  integration_test/
  pubspec.yaml
```

## Naming Conventions

- Files: `snake_case.dart` (Flutter), `snake_case.py` (backend).
- Classes: `PascalCase`.
- API paths: kebab-case resource names, versioned `/api/v1`.
- DB tables: plural `snake_case`.

## Recommended Dependencies

### Backend
- FastAPI
- Uvicorn
- SQLAlchemy
- Alembic
- Pydantic
- httpx
- google-api-python-client

### Flutter
- flutter_riverpod
- go_router
- dio
- freezed
- json_serializable
- drift (or isar)
