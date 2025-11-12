# Create KMS Keyring
resource "google_kms_key_ring" "reddit_secrets" {
  name     = var.keyring_name
  location = var.location
  project  = var.project_id
}

# Create KMS Crypto Key
resource "google_kms_crypto_key" "reddit_token_key" {
  name     = var.key_name
  key_ring = google_kms_key_ring.reddit_secrets.id

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}



