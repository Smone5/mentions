# Terraform → Vercel URL Sync

Quick reference for syncing Cloud Run backend URLs to Vercel.

---

## Quick Commands

### Get All Backend URLs

```bash
# From project root
./scripts/get-terraform-urls.sh
```

### Get Single Environment URL

```bash
cd mentions_terraform/environments/dev
terraform output backend_url
```

### Update Vercel (Manual)

1. Get URL: `terraform output backend_url`
2. Go to Vercel → Settings → Environment Variables
3. Add/Update: `NEXT_PUBLIC_API_URL` = `<terraform-output-url>`
4. Select environment: Development (dev) / Preview (staging) / Production (prod)
5. Redeploy

---

## Environment Mapping

| Terraform | Vercel Environment | Branch |
|-----------|-------------------|--------|
| `dev` | Development | `develop` |
| `staging` | Preview | `staging` |
| `prod` | Production | `main` |

---

## After Terraform Apply

When you run `terraform apply` and deploy/update the backend:

1. **Get the URL**:
   ```bash
   terraform output backend_url
   ```

2. **Update Vercel**:
   - Dashboard → Settings → Environment Variables
   - Update `NEXT_PUBLIC_API_URL` for the corresponding environment
   - Redeploy

3. **Verify**:
   - Check Vercel deployment logs
   - Test API calls from frontend

---

See `TERRAFORM-VERCEL-SYNC.md` for detailed documentation.

