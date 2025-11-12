# Branch Setup Complete ✅

All branches have been created in all three repositories.

---

## Branch Structure

### Main Repository (`mentions`)
- ✅ `main` → Production
- ✅ `staging` → Staging
- ✅ `develop` → Development

**Repository**: https://github.com/Smone5/mentions

### Frontend Repository (`mentions-frontend`) ⭐ **Vercel uses this**
- ✅ `main` → Production
- ✅ `staging` → Staging  
- ✅ `develop` → Development

**Repository**: https://github.com/Smone5/mentions-frontend

### Backend Repository (`mentions-backend`)
- ✅ `main` → Production
- ✅ `staging` → Staging
- ✅ `develop` → Development

**Repository**: https://github.com/Smone5/mentions-backend

---

## Vercel Configuration

**Important**: Vercel will deploy from the **frontend repository** (`mentions-frontend`).

### Vercel Environment Mapping

| Frontend Branch | Vercel Environment | Purpose |
|----------------|-------------------|---------|
| `main` | Production | Live production deployment |
| `staging` | Preview | Staging/testing environment |
| `develop` | Preview/Development | Development environment |

### Vercel Setup Steps

1. **Connect Repository**: Import `mentions-frontend` repository in Vercel
2. **Set Production Branch**: `main`
3. **Configure Environment Variables**:
   - **Development**: For `develop` branch
   - **Preview**: For `staging` branch and feature branches
   - **Production**: For `main` branch

---

## Git Workflow

### Frontend Development

```bash
cd mentions_frontend

# Create feature branch
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "feat: Add new component"
git push origin feature/my-feature

# Merge to develop
git checkout develop
git merge feature/my-feature
git push origin develop
# → Triggers Development deployment in Vercel

# Merge to staging
git checkout staging
git merge develop
git push origin staging
# → Triggers Staging deployment in Vercel

# Merge to main
git checkout main
git merge staging
git push origin main
# → Triggers Production deployment in Vercel
```

### Backend Development

```bash
cd mentions_backend

# Similar workflow
git checkout -b feature/my-feature
# ... make changes ...
git push origin feature/my-feature

# Merge through develop → staging → main
```

---

## Next Steps

1. ✅ Branches created in all repositories
2. ⏳ Configure Vercel to use `mentions-frontend` repository
3. ⏳ Set up environment variables in Vercel
4. ⏳ Test deployments from each branch

---

## Quick Reference

### Check Branches

```bash
# Frontend
cd mentions_frontend && git branch -a

# Backend
cd mentions_backend && git branch -a

# Main repo
cd /Users/amelton/mentions && git branch -a
```

### Switch Branches

```bash
# Frontend
cd mentions_frontend
git checkout develop
git checkout staging
git checkout main

# Backend
cd mentions_backend
git checkout develop
git checkout staging
git checkout main
```

---

## Repository URLs

- **Main**: https://github.com/Smone5/mentions
- **Frontend**: https://github.com/Smone5/mentions-frontend ⭐ **Vercel uses this**
- **Backend**: https://github.com/Smone5/mentions-backend

