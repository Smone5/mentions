resource "google_cloud_tasks_queue" "queues" {
  for_each = var.queues

  name     = each.key
  location = var.location
  project  = var.project_id

  rate_limits {
    max_concurrent_dispatches = each.value.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.max_attempts
    max_retry_duration = each.value.max_retry_duration
  }
}



