resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each = {
    for k, v in var.secrets : k => v
    if v != ""
  }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}



