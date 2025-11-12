output "keyring_id" {
  description = "KMS Keyring ID"
  value       = google_kms_key_ring.reddit_secrets.id
}

output "crypto_key_id" {
  description = "KMS Crypto Key ID"
  value       = google_kms_crypto_key.reddit_token_key.id
}


