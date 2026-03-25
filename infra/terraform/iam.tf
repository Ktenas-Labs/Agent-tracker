# ---------- Backend Cloud Run service account ----------

resource "google_service_account" "backend" {
  account_id   = "${local.app_name}-backend"
  display_name = "Agent Tracker Backend"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "backend_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_project_iam_member" "backend_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Allows the backend service account to verify Firebase / Identity Platform ID tokens
# via the Firebase Admin SDK using Application Default Credentials (Workload Identity).
resource "google_project_iam_member" "backend_firebase_admin" {
  project = var.project_id
  role    = "roles/firebase.sdkAdminServiceAgent"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# ---------- Frontend Cloud Run service account ----------

resource "google_service_account" "frontend" {
  account_id   = "${local.app_name}-frontend"
  display_name = "Agent Tracker Frontend"

  depends_on = [google_project_service.apis]
}

# ---------- CI / CD service account ----------

resource "google_service_account" "cicd" {
  account_id   = "${local.app_name}-cicd"
  display_name = "Agent Tracker CI/CD"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "cicd_roles" {
  for_each = toset([
    "roles/run.developer",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.editor",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd.email}"
}
