output "registry_url" {
  description = "Docker registry push URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "backend_url" {
  description = "Cloud Run backend URL"
  value       = var.backend_image != "" ? google_cloud_run_v2_service.backend[0].uri : "(not deployed yet — set backend_image)"
}

output "frontend_url" {
  description = "Cloud Run frontend URL"
  value       = var.frontend_image != "" ? google_cloud_run_v2_service.frontend[0].uri : "(not deployed yet — set frontend_image)"
}

output "db_connection_name" {
  description = "Cloud SQL connection name for proxy / Cloud Run"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "backend_service_account" {
  description = "Backend Cloud Run SA email"
  value       = google_service_account.backend.email
}

output "cicd_service_account" {
  description = "CI/CD SA email (for GitHub Actions / Cloud Build)"
  value       = google_service_account.cicd.email
}
