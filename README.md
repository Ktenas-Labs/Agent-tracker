# Agent Tracker v2.0

Monorepo for:
- `backend/` FastAPI + PostgreSQL
- `frontend/` Flutter (Web, iOS, Android)
- `infra/` deployment artifacts
- `scripts/` seed/import utilities

## Quick Start

1. Copy env templates:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Run with Docker (start Docker Desktop first):
   - `./scripts/docker-up.sh` or `docker compose up --build`
3. Backend API: `http://localhost:8000/docs`
4. Flutter web: `http://localhost:8080`

### Local dev (hot reload)

Uses the same Compose file plus overrides so API and Flutter web reload on file changes:

- `./scripts/dev.sh`  
  (same as `docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build`)

### Dev Container (Cursor / VS Code)

Open the repo in a Dev Container (`.devcontainer/`): Python 3.12, Flutter (web), PostgreSQL client, and Docker CLI so you can run Compose from the container. After the container builds, `post-create` installs backend deps into `backend/.venv` and runs `flutter pub get` in `frontend/`.

### Authentication (Google Cloud Identity Platform)

Production sign-in uses **Firebase Auth** (Google Cloud **Identity Platform**): the Flutter app obtains a Firebase ID token after Google Sign-In; the API verifies it with the **Firebase Admin SDK** and issues the app’s own JWT for subsequent requests.

1. In [Google Cloud Console](https://console.cloud.google.com/), enable **Identity Platform** (or add Firebase to the project) and configure **Google** as a sign-in provider.
2. Create a **service account** with permission to verify ID tokens (Firebase Admin SDK uses the project’s default credentials or a JSON key).
3. Backend: set `FIREBASE_AUTH_ENABLED=true`, and either `FIREBASE_CREDENTIALS_PATH` to the service account JSON file or `GOOGLE_APPLICATION_CREDENTIALS` to the same path (also used on Cloud Run / GKE with workload identity).
4. Flutter: run `dart pub global activate flutterfire_cli` then `flutterfire configure` to generate real `lib/firebase_options.dart` (replace the placeholders in-repo).

The legacy OAuth redirect flow (`/auth/google/login` → `/auth/google/callback`) remains for exchanging refresh tokens for **Google Workspace APIs** (Calendar, Gmail, etc.). **Mock login** is available when `ALLOW_MOCK_AUTH=true` (development only).
