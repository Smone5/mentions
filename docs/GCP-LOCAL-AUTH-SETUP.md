# Google Cloud Local Authentication Setup

## Problem

When running the backend locally, you may encounter repeated authentication errors:

```
google.auth.exceptions.RefreshError: Reauthentication is needed. 
Please run `gcloud auth application-default login` to reauthenticate.
```

This happens because `gcloud auth application-default login` creates credentials that expire after a certain period, requiring you to re-authenticate frequently.

## Solution

Use a **service account key file** instead. Service account keys never expire and work seamlessly for local development.

---

## Quick Setup (Automated)

Run the setup script:

```bash
./scripts/setup-local-gcp-auth.sh
```

This script will:
1. ✅ Check gcloud CLI is installed
2. ✅ Verify you're authenticated
3. ✅ Create a service account (if it doesn't exist)
4. ✅ Grant KMS permissions
5. ✅ Create and download a key file
6. ✅ Set proper file permissions

The key file will be saved to: `~/.config/gcp/mention001-local-dev-key.json`

---

## Manual Setup

If you prefer to set up manually:

### Step 1: Create Service Account

```bash
gcloud config set project mention001

gcloud iam service-accounts create mentions-backend-local \
  --display-name="Mentions Backend Local Development" \
  --description="Service account for local development"
```

### Step 2: Grant KMS Permissions

```bash
SERVICE_ACCOUNT="mentions-backend-local@mention001.iam.gserviceaccount.com"

gcloud kms keys add-iam-policy-binding reddit-token-key \
  --location=us-central1 \
  --keyring=reddit-secrets \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
```

### Step 3: Create and Download Key

```bash
# Create directory
mkdir -p ~/.config/gcp

# Create and download key
gcloud iam service-accounts keys create \
  ~/.config/gcp/mention001-local-dev-key.json \
  --iam-account=mentions-backend-local@mention001.iam.gserviceaccount.com

# Set secure permissions
chmod 600 ~/.config/gcp/mention001-local-dev-key.json
```

---

## Configure Your Application

### Option 1: Environment Variable (Recommended)

Add to your `.env` file:

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp/mention001-local-dev-key.json
```

Or export in your shell:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp/mention001-local-dev-key.json
```

### Option 2: Use Full Path

If using `~` doesn't work, use the full path:

```bash
GOOGLE_APPLICATION_CREDENTIALS=/Users/yourusername/.config/gcp/mention001-local-dev-key.json
```

---

## How It Works

The updated KMS client (`mentions_backend/core/kms.py`) will:

1. **First**: Check for `GOOGLE_APPLICATION_CREDENTIALS` environment variable or config setting
2. **If found**: Use the service account key file (never expires!)
3. **If not found**: Fall back to Application Default Credentials (ADC)
   - On Cloud Run: Uses the service account automatically
   - Locally: Requires `gcloud auth application-default login` (expires)

---

## Security Notes

⚠️ **IMPORTANT**: Never commit service account keys to git!

- The key file is already in `.gitignore`
- Service account keys have the same permissions as the service account
- If a key is compromised, delete it immediately:
  ```bash
  gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=mentions-backend-local@mention001.iam.gserviceaccount.com
  ```

---

## Troubleshooting

### "Permission denied" errors

Make sure the service account has the required permissions:

```bash
# Check current permissions
gcloud projects get-iam-policy mention001 \
  --flatten="bindings[].members" \
  --filter="bindings.members:mentions-backend-local@mention001.iam.gserviceaccount.com"
```

### "File not found" errors

1. Check the file exists:
   ```bash
   ls -la ~/.config/gcp/mention001-local-dev-key.json
   ```

2. Use absolute path instead of `~`:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=$(realpath ~/.config/gcp/mention001-local-dev-key.json)
   ```

### Still getting authentication errors

1. Verify the key file is valid JSON:
   ```bash
   cat ~/.config/gcp/mention001-local-dev-key.json | jq .
   ```

2. Test authentication:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp/mention001-local-dev-key.json
   gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
   ```

---

## Production vs Local

| Environment | Authentication Method | Expires? |
|------------|----------------------|----------|
| **Local Dev** | Service account key file | ❌ Never |
| **Cloud Run** | Service account (automatic) | ❌ Never |
| **Local (ADC)** | `gcloud auth application-default login` | ✅ Yes (periodic) |

For local development, **always use a service account key file** to avoid re-authentication.

---

## Next Steps

After setting up authentication:

1. ✅ Test KMS encryption/decryption works
2. ✅ Run your backend locally without auth errors
3. ✅ Continue development without interruption!

If you encounter any issues, check the logs for detailed error messages.



