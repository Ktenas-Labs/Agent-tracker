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
    # Google Cloud Identity Platform (Firebase Auth): verify ID tokens with Firebase Admin SDK
    firebase_auth_enabled: bool = False
    firebase_credentials_path: str = ""
    allowed_origins: str = "http://localhost:8080"
    allowed_hosts: str = "localhost,127.0.0.1"
    allow_mock_auth: bool = True
    create_tables_on_startup: bool = False
    cookie_secure: bool = False
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()  # type: ignore[call-arg]
