locals {
  frontend_image = var.frontend_image != "" ? var.frontend_image : "${var.region}-docker.pkg.dev/${var.project_id}/${local.app_name}/frontend:latest"
}

resource "google_cloud_run_v2_service" "frontend" {
  count    = var.frontend_image != "" ? 1 : 0
  name     = "${local.app_name}-web"
  location = var.region

  template {
    service_account = google_service_account.frontend.email

    scaling {
      min_instance_count = var.frontend_min_instances
      max_instance_count = var.frontend_max_instances
    }

    containers {
      image = local.frontend_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "API_BASE_URL"
        value = var.backend_api_url
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Uncomment to make the frontend publicly accessible
# resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
#   count    = var.frontend_image != "" ? 1 : 0
#   name     = google_cloud_run_v2_service.frontend[0].name
#   location = var.region
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }
