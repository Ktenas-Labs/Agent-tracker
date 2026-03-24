locals {
  backend_image = var.backend_image != "" ? var.backend_image : "${var.region}-docker.pkg.dev/${var.project_id}/${local.app_name}/backend:latest"
}

resource "google_cloud_run_v2_service" "backend" {
  count    = var.backend_image != "" ? 1 : 0
  name     = "${local.app_name}-api"
  location = var.region

  template {
    service_account = google_service_account.backend.email

    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = local.backend_image

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "ENV"
        value = var.environment
      }

      env {
        name  = "APP_NAME"
        value = "Agent Tracker API"
      }

      env {
        name  = "ALLOWED_ORIGINS"
        value = "*"
      }

      env {
        name  = "ALLOWED_HOSTS"
        value = "*"
      }

      env {
        name  = "ALLOW_MOCK_AUTH"
        value = var.environment == "prod" ? "false" : "true"
      }

      env {
        name  = "COOKIE_SECURE"
        value = "true"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.secrets["database-url"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.secrets["jwt-secret"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_secret.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/api/v1/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/api/v1/health"
        }
        period_seconds = 30
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_version.secrets,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "backend_public" {
  count    = var.backend_image != "" ? 1 : 0
  name     = google_cloud_run_v2_service.backend[0].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
