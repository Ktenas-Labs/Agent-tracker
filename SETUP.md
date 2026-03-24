# Setup Instructions

## Local Development

1. Copy env files:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Start services:
   - `docker compose up --build`
3. Open:
   - Backend docs: `http://localhost:8000/docs`
   - Frontend: `http://localhost:8080`

## Seed Data

1. Generate demo seed:
   - `python3 scripts/generate_demo_seed.py`
2. Load seed:
   - `python3 scripts/load_seed.py`
3. Import raw workbook:
   - `python3 scripts/import_excel.py`

## Production Notes

- Deploy backend container to Cloud Run.
- Provision Cloud SQL PostgreSQL and set `DATABASE_URL`.
- Store OAuth and API credentials in Secret Manager.
