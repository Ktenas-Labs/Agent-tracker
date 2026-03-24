from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
import time

from app.core.config import settings
from app.db.session import Base, engine
from app.api.v1.routes_core import router as core_router
from app.api.v1.routes_operations import router as operations_router
from app.api.v1.routes_auth import router as auth_router
from app.api.v1.routes_integrations import router as integrations_router
from app.api.v1.routes_reports import router as reports_router


app = FastAPI(title=settings.app_name)
_rate_window: dict[str, tuple[int, float]] = {}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
        response.headers["Cache-Control"] = "no-store"
        return response


class SimpleRateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in {"/api/v1/health"} or request.method == "OPTIONS":
            return await call_next(request)
        now = time.time()
        key = request.client.host if request.client else "unknown"
        count, start = _rate_window.get(key, (0, now))
        if now - start > settings.rate_limit_window_seconds:
            count, start = 0, now
        count += 1
        _rate_window[key] = (count, start)
        if count > settings.rate_limit_requests:
            return JSONResponse(
                {"detail": "Rate limit exceeded"},
                status_code=429,
                headers={"Retry-After": str(settings.rate_limit_window_seconds)},
            )
        return await call_next(request)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.allowed_origins.split(",") if o.strip()],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=[h.strip() for h in settings.allowed_hosts.split(",") if h.strip()],
)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(SimpleRateLimitMiddleware)

if settings.create_tables_on_startup:
    Base.metadata.create_all(bind=engine)


@app.get("/", include_in_schema=False)
def root_landing():
    """Browser-friendly pointer: API docs here, Flutter UI is a separate origin (usually :8080)."""
    return HTMLResponse(
        """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Agent Tracker</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; color: #1a1a1a; }
    a { color: #0d47a1; }
    code { background: #f0f0f0; padding: 0.1em 0.35em; border-radius: 4px; font-size: 0.9em; }
  </style>
</head>
<body>
  <h1>Agent Tracker</h1>
  <p>You are on the <strong>API server</strong>. <code>/docs</code> is only the interactive REST explorer (Swagger), not the product UI.</p>
  <p><a href="/docs">Open API docs</a></p>
  <p>The <strong>Flutter web app</strong> (login, dashboard, etc.) runs on another port, usually <strong>8080</strong>:</p>
  <p><a href="http://localhost:8080">Open web app → http://localhost:8080</a></p>
  <p>Start the UI from the repo root: <code>docker compose up --build</code>, or locally:
  <code>cd frontend && flutter pub get && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0</code>.</p>
</body>
</html>"""
    )


app.include_router(core_router, prefix="/api/v1", tags=["core"])
app.include_router(operations_router, prefix="/api/v1", tags=["operations"])
app.include_router(auth_router, prefix="/api/v1", tags=["auth"])
app.include_router(integrations_router, prefix="/api/v1", tags=["integrations"])
app.include_router(reports_router, prefix="/api/v1", tags=["reports"])
