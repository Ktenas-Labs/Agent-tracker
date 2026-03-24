variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "db_tier" {
  description = "Cloud SQL machine type"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "agent_tracker"
}

variable "db_user" {
  description = "PostgreSQL user name"
  type        = string
  default     = "agent_tracker"
}

variable "backend_image" {
  description = "Backend container image (set by CI or manually)"
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Frontend container image (set by CI or manually)"
  type        = string
  default     = ""
}

variable "backend_min_instances" {
  description = "Minimum Cloud Run instances for the backend"
  type        = number
  default     = 0
}

variable "backend_max_instances" {
  description = "Maximum Cloud Run instances for the backend"
  type        = number
  default     = 4
}

variable "frontend_min_instances" {
  description = "Minimum Cloud Run instances for the frontend"
  type        = number
  default     = 0
}

variable "frontend_max_instances" {
  description = "Maximum Cloud Run instances for the frontend"
  type        = number
  default     = 2
}

variable "backend_api_url" {
  description = "Backend API base URL for the frontend (set after first backend deploy)"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Custom domain for the frontend (optional, leave empty to skip)"
  type        = string
  default     = ""
}
