# Infrastructure — Google Cloud (Terraform)

All GCP resources for Agent Tracker are managed in `terraform/`.

## Resources provisioned

| Resource | File | Notes |
|---|---|---|
| GCP APIs | `main.tf` | Enables Cloud Run, Cloud SQL, Secret Manager, etc. |
| VPC + VPC Connector | `network.tf` | Private networking for Cloud Run → Cloud SQL |
| Cloud SQL (Postgres 16) | `cloud-sql.tf` | Private IP, auto-resize, prod backups + PITR |
| Secret Manager | `secrets.tf` | DATABASE_URL, JWT_SECRET, Google OAuth creds |
| Artifact Registry | `artifact-registry.tf` | Docker repo, keeps last 10 images |
| Cloud Run — backend | `cloud-run-backend.tf` | FastAPI, wired to SQL + secrets via env |
| Cloud Run — frontend | `cloud-run-frontend.tf` | Flutter web build |
| IAM | `iam.tf` | Service accounts: backend, frontend, CI/CD |
| Outputs | `outputs.tf` | URLs, connection name, SA emails |

## Prerequisites

1. A GCP project with billing enabled
2. `gcloud` CLI + `terraform` (both included in the dev container)
3. Authenticate:

```bash
gcloud auth login
gcloud auth application-default login
```

## First-time setup

```bash
cd infra/terraform

# Create your tfvars from the example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_id at minimum

terraform init
terraform plan          # review what will be created
terraform apply         # provision everything
```

Cloud SQL takes ~5-10 minutes to provision. After apply you'll see outputs like:

```
registry_url            = "us-central1-docker.pkg.dev/my-project/agent-tracker"
db_connection_name      = "my-project:us-central1:agent-tracker-dev"
backend_url             = "(not deployed yet — set backend_image)"
cicd_service_account    = "agent-tracker-cicd@my-project.iam.gserviceaccount.com"
```

## Deploying the app

Cloud Run services are only created when you set `backend_image` / `frontend_image`. Build and push first:

```bash
# Authenticate Docker to Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build + push backend
docker build -t us-central1-docker.pkg.dev/PROJECT/agent-tracker/backend:latest ./backend
docker push us-central1-docker.pkg.dev/PROJECT/agent-tracker/backend:latest

# Build + push frontend (flutter build web → nginx, or use existing Dockerfile)
docker build -t us-central1-docker.pkg.dev/PROJECT/agent-tracker/frontend:latest ./frontend
docker push us-central1-docker.pkg.dev/PROJECT/agent-tracker/frontend:latest

# Now deploy
terraform apply -var backend_image="us-central1-docker.pkg.dev/PROJECT/agent-tracker/backend:latest" \
                -var frontend_image="us-central1-docker.pkg.dev/PROJECT/agent-tracker/frontend:latest"
```

## Google OAuth secrets

The `google-client-id` and `google-client-secret` Secret Manager entries are created empty. Populate them after setting up OAuth in the GCP Console:

```bash
echo -n "YOUR_CLIENT_ID" | gcloud secrets versions add agent-tracker-google-client-id --data-file=-
echo -n "YOUR_CLIENT_SECRET" | gcloud secrets versions add agent-tracker-google-client-secret --data-file=-
```

## Remote state (recommended for teams)

Uncomment the `backend "gcs"` block in `main.tf` after creating a bucket:

```bash
gsutil mb -l us-central1 gs://YOUR_PROJECT-tfstate
```

## Destroying

```bash
terraform destroy
```

Note: prod environments have `deletion_protection = true` on Cloud SQL. To destroy, first set `environment = "dev"` or remove the protection manually.
