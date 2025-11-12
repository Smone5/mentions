variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP Location"
  type        = string
}

variable "kms_crypto_key_id" {
  description = "KMS crypto key ID for encryption/decryption"
  type        = string
}


