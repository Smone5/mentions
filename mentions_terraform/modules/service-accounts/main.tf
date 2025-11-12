# Backend service account
resource "google_service_account" "backend" {
  account_id   = "mentions-backend"
  display_name = "Mentions Backend Service Account"
  project      = var.project_id
}

# Grant KMS permissions
resource "google_kms_crypto_key_iam_member" "backend_kms" {
  crypto_key_id = var.kms_crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.backend.email}"
}

# Grant Secret Manager access
resource "google_project_iam_member" "backend_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Grant Cloud Tasks enqueuer
resource "google_project_iam_member" "backend_tasks" {
  project = var.project_id
  role    = "roles/cloudtasks.enqueuer"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Grant Cloud Run invoker (for Cloud Tasks to invoke Cloud Run)
resource "google_project_iam_member" "backend_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.backend.email}"
}



