# Git Workflow Guide

## Repository Structure

This project uses a **hybrid monorepo approach** with Git submodules:

```
mentions/ (main repository)
├── docs/
├── mentions_backend/ (Git submodule - separate repository)
├── mentions_frontend/ (Git submodule - separate repository)
└── mentions_terraform/
```

### Why This Structure?

- **Cursor AI Compatibility**: Single repository for seamless AI-powered development
- **Independent Deployment**: Backend and frontend can be deployed separately
- **Team Flexibility**: Teams can work on frontend/backend independently
- **Version Control**: Each component maintains its own Git history

## Working with the Repository

### Initial Clone (for new developers)

```bash
# Clone the main repository with all submodules
git clone --recurse-submodules <main-repo-url>

# Or if you already cloned without submodules:
git clone <main-repo-url>
cd mentions
git submodule init
git submodule update
```

### Daily Development Workflow

#### Working on Backend

```bash
cd mentions_backend

# Make your changes
# ... edit files ...

# Commit to backend repository
git add .
git commit -m "feat: Add new API endpoint"
git push origin main

# Update the main repository to reference the new commit
cd ..
git add mentions_backend
git commit -m "Update backend submodule"
git push origin main
```

#### Working on Frontend

```bash
cd mentions_frontend

# Make your changes
# ... edit files ...

# Commit to frontend repository
git add .
git commit -m "feat: Add new dashboard component"
git push origin main

# Update the main repository to reference the new commit
cd ..
git add mentions_frontend
git commit -m "Update frontend submodule"
git push origin main
```

#### Working on Documentation or Terraform

```bash
# These are part of the main repository
git add docs/
git commit -m "docs: Update API documentation"
git push origin main
```

### Updating Submodules

When a teammate updates a submodule:

```bash
# Pull latest changes from main repository
git pull origin main

# Update all submodules to the referenced commits
git submodule update --remote --merge
```

### Creating Feature Branches

#### For Backend/Frontend Changes

```bash
# Create branch in the submodule
cd mentions_backend
git checkout -b feature/new-endpoint
# ... make changes ...
git commit -m "feat: Add new endpoint"
git push origin feature/new-endpoint

# Create PR in backend repository
# After merge, update main repo
cd ..
git checkout -b update/backend-feature
git add mentions_backend
git commit -m "Update backend with new endpoint feature"
git push origin update/backend-feature
```

#### For Documentation/Infrastructure Changes

```bash
# Create branch in main repository
git checkout -b docs/update-api-guide
# ... make changes ...
git commit -m "docs: Update API guide"
git push origin docs/update-api-guide
```

## Setting Up Remote Repositories

### Option 1: GitHub (Recommended)

1. **Create three repositories on GitHub**:
   - `mentions` (main repository)
   - `mentions-backend`
   - `mentions-frontend`

2. **Add remotes to existing repositories**:

```bash
# Main repository
cd /Users/amelton/mentions
git remote add origin https://github.com/yourusername/mentions.git
git push -u origin main

# Backend
cd mentions_backend
git remote add origin https://github.com/yourusername/mentions-backend.git
git push -u origin main

# Frontend
cd mentions_frontend
git remote add origin https://github.com/yourusername/mentions-frontend.git
git push -u origin main
```

3. **Update submodule URLs in main repository**:

Edit `.gitmodules`:
```ini
[submodule "mentions_backend"]
    path = mentions_backend
    url = https://github.com/yourusername/mentions-backend.git
[submodule "mentions_frontend"]
    path = mentions_frontend
    url = https://github.com/yourusername/mentions-frontend.git
```

Then commit:
```bash
cd /Users/amelton/mentions
git add .gitmodules
git commit -m "Update submodule URLs to GitHub remotes"
git push origin main
```

### Option 2: GitLab or Bitbucket

Same process as GitHub, just replace the URLs with your GitLab/Bitbucket URLs.

## Common Commands

### Check Status Across All Repos

```bash
# Main repo status
git status

# Backend status
cd mentions_backend && git status && cd ..

# Frontend status
cd mentions_frontend && git status && cd ..

# Or use this one-liner:
git status && echo "---Backend---" && git -C mentions_backend status && echo "---Frontend---" && git -C mentions_frontend status
```

### Pull Latest Changes from All Repos

```bash
# Update main and all submodules
git pull origin main
git submodule update --remote --merge
```

### Push Changes to All Repos

```bash
# Backend
cd mentions_backend
git push origin main
cd ..

# Frontend
cd mentions_frontend
git push origin main
cd ..

# Main repo
git add mentions_backend mentions_frontend
git commit -m "Update submodules"
git push origin main
```

## Best Practices

1. **Commit Frequently**: Make small, focused commits with clear messages
2. **Sync Regularly**: Pull and update submodules daily
3. **Use Branches**: Create feature branches for new work
4. **Update Main Repo**: After pushing to backend/frontend, update the main repo reference
5. **Clear Commit Messages**: Use conventional commits (feat:, fix:, docs:, etc.)

## Troubleshooting

### Submodule is in 'detached HEAD' state

```bash
cd mentions_backend  # or mentions_frontend
git checkout main
git pull origin main
```

### Submodule changes not showing up

```bash
cd /Users/amelton/mentions
git submodule update --remote --merge
```

### Accidentally committed to wrong repo

```bash
# If you committed backend code to main repo:
git reset HEAD~1  # Undo the commit
cd mentions_backend
git add .
git commit -m "Your message"
```

### Reset submodule to last committed state

```bash
cd /Users/amelton/mentions
git submodule update --init --recursive
```

## For Cursor AI

Cursor works seamlessly with this setup because:
- All code is accessible in one workspace
- Submodules are just directories from Cursor's perspective
- You can edit any file across backend/frontend/docs simultaneously

Just remember to commit changes to the appropriate repository (main vs submodule).

## Quick Reference

```bash
# Clone with submodules
git clone --recurse-submodules <url>

# Update all submodules
git submodule update --remote --merge

# Initialize submodules after clone
git submodule init && git submodule update

# Check all repos status
git status && git submodule foreach 'git status'

# Pull all repos
git pull && git submodule foreach 'git pull origin main'
```



