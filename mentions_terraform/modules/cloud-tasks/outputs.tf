output "queue_names" {
  description = "Map of queue names to queue resource names"
  value       = {
    for k, v in google_cloud_tasks_queue.queues : k => v.name
  }
}


