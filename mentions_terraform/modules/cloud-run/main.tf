variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image" {
  description = "Container image URL"
  type        = string
}

variable "service_account_email" {
  type = string
}

variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from Secret Manager"
  type = map(object({
    secret_name = string
    version     = string
  }))
  default = {}
}

variable "allow_unauthenticated" {
  type    = bool
  default = false
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "cpu" {
  type    = string
  default = "1"
}

resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  location = var.location
  project  = var.project_id

  template {
    service_account = var.service_account_email

    scaling {
      max_instance_count = var.max_instances
      min_instance_count = var.min_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          memory = var.memory
          cpu    = var.cpu
        }
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      ports {
        container_port = 8000
      }
    }

    timeout = "300s"
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Allow public access if specified
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  value = google_cloud_run_v2_service.service.uri
}

output "service_name" {
  value = google_cloud_run_v2_service.service.name
}


