variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "secrets" {
  description = "Map of secret names to initial values (use empty string if setting manually)"
  type        = map(string)
  default     = {}
}


