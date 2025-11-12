output "secret_ids" {
  description = "Map of secret names to secret IDs"
  value       = {
    for k, v in google_secret_manager_secret.secrets : k => v.id
  }
}


