resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = local.app_name
  format        = "DOCKER"
  description   = "Container images for Agent Tracker"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  depends_on = [google_project_service.apis]
}
