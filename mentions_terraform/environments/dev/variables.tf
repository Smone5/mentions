variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "mention001"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "billing_account" {
  description = "GCP Billing Account ID"
  type        = string
}

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "gcr.io/mention001/backend:latest"
}

variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
}


