# Vercel Build Error Fix

## Problem

Vercel build is failing with:
```
Error: No Next.js version detected. Make sure your package.json has "next" in either "dependencies" or "devDependencies". Also check your Root Directory setting matches the directory of your package.json file.
```

## Solution

The issue is that Vercel needs to know where your `package.json` file is located.

### Fix Option 1: Set Root Directory in Vercel (Recommended)

1. Go to your Vercel project dashboard
2. Go to **Settings** → **General**
3. Find **Root Directory** setting
4. Set it to: `mentions_frontend` (if frontend is in a subdirectory) OR `.` (if package.json is at root)
5. Click **Save**
6. Redeploy

### Fix Option 2: If Frontend is Separate Repo

If `mentions-frontend` is a separate GitHub repository (not a monorepo):

1. Make sure `package.json` is at the root of that repository
2. Root Directory should be: `.` (default)
3. Verify the repository structure matches what Vercel expects

### Fix Option 3: Use vercel.json

A `vercel.json` file has been created in `mentions_frontend/` to help with configuration.

If your frontend is in a separate repo, copy this file to the root of that repo.

---

## Quick Fix Steps

1. **Check your repository structure**:
   - If `package.json` is at root → Root Directory = `.`
   - If `package.json` is in `mentions_frontend/` → Root Directory = `mentions_frontend`

2. **Update Vercel Settings**:
   - Settings → General → Root Directory
   - Set to the correct path
   - Save

3. **Redeploy**:
   - Go to Deployments
   - Click "Redeploy" on the latest deployment
   - Or push a new commit

---

## Verify Configuration

After fixing, verify:

- ✅ Root Directory points to directory containing `package.json`
- ✅ `package.json` has `next` in dependencies
- ✅ Build command is `npm run build` (or default)
- ✅ Install command is `npm install` (or default)

---

## Current Status

- ✅ `vercel.json` created in `mentions_frontend/`
- ⏳ Update Root Directory in Vercel project settings
- ⏳ Redeploy to test

