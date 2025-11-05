# Reddit Reply Assistant - Development Plan Index

## 🚀 START HERE

**For AI Agents**: Read **[29-AI-EXECUTION-GUIDE.md](./29-AI-EXECUTION-GUIDE.md)** first for how to use these docs effectively.

**For Humans**: Read **[00-QUICK-START.md](./00-QUICK-START.md)** for 5-minute overview and next steps.

**⚠️ CRITICAL**: Read **[22-HARD-RULES.md](./22-HARD-RULES.md)** before touching any posting code. These are non-negotiable.

---

## Overview
This directory contains the complete build plan for the Reddit Reply Assistant, organized into actionable documents for systematic development.

## Repository Organization

**All backend code goes in**: `mentions_backend/`  
**All frontend code goes in**: `mentions_frontend/`  
**All Terraform infrastructure code goes in**: `mentions_terraform/`  
**All documentation goes in**: `docs/`

See **[20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)** for complete directory structure, file organization, and development workflow.

## Core Concept
For each company:
1. Take their **keywords**, **goal**, and **company data**
2. Use Reddit + LLMs to **find good subreddits** and **good threads**
3. Use **RAG** to ground answers in company data
4. Draft a **no-links** reply with variation and quality checks
5. Show it in a strong **review UI** for human edit & approval
6. Post via Reddit API with safety controls
7. Verify visibility
8. Log everything for **future RL / supervised fine-tuning**

## Document Structure

### 0. Quick Start & Critical Docs (Read First!)
- **[00-QUICK-START.md](./00-QUICK-START.md)** ⚡ - Read this first! 5-minute overview
- **[22-HARD-RULES.md](./22-HARD-RULES.md)** ⚠️ - NON-NEGOTIABLE constraints (MUST READ)
- **[31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md)** 📋 - Exact dependency graph and build order
- **[29-AI-EXECUTION-GUIDE.md](./29-AI-EXECUTION-GUIDE.md)** 🤖 - For AI agents: how to use these docs

### 1. Foundation Documents
- **[01-TECH-STACK.md](./01-TECH-STACK.md)** - Complete technology stack and architecture
- **[02-ENVIRONMENT-SETUP.md](./02-ENVIRONMENT-SETUP.md)** - Environment configuration and secrets management
- **[28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)** - Terraform infrastructure as code for GCP
- **[03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md)** - Complete Postgres schema with RLS
- **[20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)** - File and folder organization

### 2. Milestone Plans
- **[M1-FOUNDATIONS.md](./M1-FOUNDATIONS.md)** - Auth, DB, Reddit Connect
- **[M2-GENERATION-FLOW.md](./M2-GENERATION-FLOW.md)** - Subreddit gating, RAG, drafts
- **[M3-REVIEW-UI.md](./M3-REVIEW-UI.md)** - Review UI & approve/post flow
- **[M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md)** - Posting volume, history, RL logging
- **[M5-PRODUCTION.md](./M5-PRODUCTION.md)** - Staging, RLS, tests, metrics

### 3. Implementation Guides - Backend
- **[10-LANGGRAPH-FLOW.md](./10-LANGGRAPH-FLOW.md)** - Complete LangGraph generation pipeline
- **[11-RAG-IMPLEMENTATION.md](./11-RAG-IMPLEMENTATION.md)** - RAG ingestion and retrieval
- **[12-POSTING-FLOW.md](./12-POSTING-FLOW.md)** - Approve & post with verification
- **[13-RATE-LIMITING.md](./13-RATE-LIMITING.md)** - Volume controls and eligibility
- **[21-API-ENDPOINTS.md](./21-API-ENDPOINTS.md)** - Complete backend API reference
- **[34-SCHEDULED-DISCOVERY.md](./34-SCHEDULED-DISCOVERY.md)** - Automated subreddit/thread discovery

### 4. Implementation Guides - Frontend
- **[14-UI-SPECIFICATIONS.md](./14-UI-SPECIFICATIONS.md)** - Detailed UI/UX specifications
- **[25-FRONTEND-PAGES.md](./25-FRONTEND-PAGES.md)** - Complete page structure and navigation
- **[27-RESPONSIVE-SEO.md](./27-RESPONSIVE-SEO.md)** - Mobile/desktop responsive design and SEO optimization

### 5. Testing & Quality
- **[15-TESTING-PLAN.md](./15-TESTING-PLAN.md)** - Unit, integration, and E2E tests
- **[16-RL-FINE-TUNING.md](./16-RL-FINE-TUNING.md)** - Training data collection strategy
- **[23-OBSERVABILITY.md](./23-OBSERVABILITY.md)** - Logging, metrics, alerts
- **[24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md)** - Structured logging and debugging strategies

### 6. Reference Documents
- **[17-GPT5-PROMPTING-GUIDE.md](./17-GPT5-PROMPTING-GUIDE.md)** - OpenAI GPT-5 best practices
- **[18-REDDIT-API-REFERENCE.md](./18-REDDIT-API-REFERENCE.md)** - Complete Reddit API reference
- **[19-COMPANY-FINE-TUNING.md](./19-COMPANY-FINE-TUNING.md)** - Company-specific model training
- **[26-PRICING-BILLING.md](./26-PRICING-BILLING.md)** - Stripe subscription management

### 7. AI Development Helpers
- **[30-CODE-CONVENTIONS.md](./30-CODE-CONVENTIONS.md)** - Coding standards (Python, TypeScript)
- **[32-CODE-TEMPLATES.md](./32-CODE-TEMPLATES.md)** - Reusable code scaffolds
- **[33-TROUBLESHOOTING.md](./33-TROUBLESHOOTING.md)** - Common issues and solutions

## Development Timeline

### Phase 1: Foundation (Weeks 1-2)
→ **M1-FOUNDATIONS.md**
- Supabase auth and database
- Reddit OAuth integration
- Basic FastAPI scaffold
- GCP infrastructure setup

### Phase 2: Core Generation (Weeks 3-4)
→ **M2-GENERATION-FLOW.md**
- LangGraph pipeline implementation
- Subreddit gating with LLM judges
- RAG retrieval system
- Draft composition and variation

### Phase 3: Review & Posting (Weeks 5-6)
→ **M3-REVIEW-UI.md**
- Inbox with filtering/sorting
- Draft detail view with editing
- Approval flow
- Posting with verification

### Phase 4: Scale & Learn (Weeks 7-8)
→ **M4-VOLUME-LEARNING.md**
- Posting volume controls
- History-based reuse logic
- Training event logging
- Nightly learning jobs

### Phase 5: Production Ready (Weeks 9-10)
→ **M5-PRODUCTION.md**
- Multi-environment setup
- Row Level Security
- Comprehensive testing
- Monitoring and alerts

## Key Technologies
- **Frontend**: Next.js 14, TypeScript, Tailwind, Supabase Auth (see [27-RESPONSIVE-SEO.md](./27-RESPONSIVE-SEO.md))
- **Backend**: FastAPI, LangGraph, asyncpraw, Pydantic
- **Database**: Supabase Postgres with pgvector
- **Infrastructure**: GCP (Cloud Run, Cloud Tasks, Cloud Scheduler, KMS)
- **LLM**: GPT-5-mini with varying temperatures (see [17-GPT5-PROMPTING-GUIDE.md](./17-GPT5-PROMPTING-GUIDE.md))
- **Reddit**: OAuth2, one app per company, encrypted credentials (see [18-REDDIT-API-REFERENCE.md](./18-REDDIT-API-REFERENCE.md))

## Critical Policies
✅ **Human approval required** before posting  
✅ **No links** in replies (hard enforced)  
✅ **LLM gates** for subreddit and draft quality  
✅ **Encrypted storage** for Reddit credentials  
✅ **Rate limiting** to avoid spam flags  
✅ **Verification** of post visibility  
✅ **RL/SFT logging** for continuous improvement  

## Quick Start for Developers

**For AI Agents**:
1. Read **[29-AI-EXECUTION-GUIDE.md](./29-AI-EXECUTION-GUIDE.md)** - How to use these docs
2. Read **[22-HARD-RULES.md](./22-HARD-RULES.md)** - Non-negotiable constraints
3. Follow **[31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md)** - Exact build order
4. Reference **[32-CODE-TEMPLATES.md](./32-CODE-TEMPLATES.md)** - Code scaffolds
5. Use **[33-TROUBLESHOOTING.md](./33-TROUBLESHOOTING.md)** - When stuck

**For Human Developers**:
1. Read **[00-QUICK-START.md](./00-QUICK-START.md)** - 5-minute overview
2. Read **[22-HARD-RULES.md](./22-HARD-RULES.md)** - Critical constraints
3. Read **[20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)** - Folder organization
4. Read **[01-TECH-STACK.md](./01-TECH-STACK.md)** - Architecture overview
5. Follow **[02-ENVIRONMENT-SETUP.md](./02-ENVIRONMENT-SETUP.md)** or **[28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)**
6. Run **[03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md)** migrations
7. Start with **[M1-FOUNDATIONS.md](./M1-FOUNDATIONS.md)** milestone
8. Follow milestone documents in sequence (M1 → M2 → M3 → M4 → M5)
9. Refer to implementation guides (sections 3-4) as needed
10. Check **[30-CODE-CONVENTIONS.md](./30-CODE-CONVENTIONS.md)** for coding standards

## Success Criteria
- [ ] Users can sign up and connect Reddit accounts
- [ ] System finds good subreddits and filters bad ones
- [ ] Drafts are grounded in company data via RAG
- [ ] Review UI enables efficient human oversight
- [ ] Posts appear on Reddit and are verified visible
- [ ] Volume controls prevent spam flags
- [ ] All interactions logged for training
- [ ] Multi-tenant isolation with RLS
- [ ] Safe staging environment
- [ ] ~200 posts/week capacity across accounts

