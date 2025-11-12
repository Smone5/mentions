variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP Location"
  type        = string
  default     = "us-central1"
}

variable "keyring_name" {
  description = "KMS Keyring name"
  type        = string
  default     = "reddit-secrets"
}

variable "key_name" {
  description = "KMS Key name"
  type        = string
  default     = "reddit-token-key"
}


