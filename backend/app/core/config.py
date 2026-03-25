from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Agent Tracker API"
    env: str = "dev"
    database_url: str
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60
    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = ""
    # Fernet key for encrypting OAuth refresh tokens at rest.
    # Generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    google_token_encryption_key: str = ""
    # Scopes requested when a user connects Google Workspace
    google_workspace_scopes: str = (
        "openid email profile "
        "https://www.googleapis.com/auth/gmail.send "
        "https://www.googleapis.com/auth/calendar.events "
        "https://www.googleapis.com/auth/drive.file "
        "https://www.googleapis.com/auth/tasks "
        "https://www.googleapis.com/auth/admin.directory.user.readonly"
    )
    # Google Workspace domain for directory sync (e.g. "ktenas.cloud")
    google_workspace_domain: str = ""
    # Google Cloud Identity Platform (Firebase Auth): verify ID tokens with Firebase Admin SDK
    firebase_auth_enabled: bool = False
    firebase_credentials_path: str = ""
    # GCP project ID — used by Firebase Admin SDK when ADC cannot auto-detect the project
    # (e.g. local dev with `gcloud auth application-default login` instead of a service account)
    firebase_project_id: str = ""
    allowed_origins: str = "http://localhost:8080"
    allowed_hosts: str = "localhost,127.0.0.1"
    allow_mock_auth: bool = True
    # When True, only users already in the DB can sign in.
    # When False, unknown Google accounts are auto-provisioned as agents.
    restrict_login_to_known_users: bool = True
    create_tables_on_startup: bool = False
    cookie_secure: bool = False
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()  # type: ignore[call-arg]
