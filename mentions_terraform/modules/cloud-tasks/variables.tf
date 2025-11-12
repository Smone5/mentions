variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP Location"
  type        = string
}

variable "queues" {
  description = "Map of queue names to configuration"
  type = map(object({
    max_concurrent_dispatches = number
    max_attempts              = number
    max_retry_duration        = string
  }))
}


