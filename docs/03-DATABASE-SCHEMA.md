# Database Schema

## Overview
Complete PostgreSQL schema for the Reddit Reply Assistant, including pgvector for RAG embeddings and Row Level Security for multi-tenant isolation.

---

## Prerequisites
```sql
-- Enable required extensions
create extension if not exists vector;
create extension if not exists "uuid-ossp";
```

---

## 1. Core Multi-Tenant Structure

### Companies
```sql
create table companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_companies_created_at on companies(created_at);
```

### User Profiles
```sql
create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  role text check (role in ('owner','admin','member')) default 'member',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_user_profiles_company_id on user_profiles(company_id);
create unique index idx_user_profiles_id_company on user_profiles(id, company_id);
```

**Notes**:
- `auth.users` is managed by Supabase Auth
- `role` determines permissions within a company
- `owner` can manage Reddit apps and billing
- `admin` can approve posts and manage prompts
- `member` can review and suggest edits

---

## 2. Keywords & Prompts

### Keywords
```sql
create table keywords (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  keyword text not null,
  is_active boolean default true,
  priority text check (priority in ('low', 'normal', 'high')) default 'normal',
  discovery_frequency_minutes int default 120,  -- How often to check (default 2 hours)
  last_discovered_at timestamptz,
  next_discovery_at timestamptz,
  total_discoveries int default 0,
  total_artifacts int default 0,
  max_artifacts_per_day int default 10,         -- Rate limit per keyword
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_keywords_company_keyword on keywords(company_id, keyword);
create index idx_keywords_next_discovery on keywords(next_discovery_at) where is_active = true;
create index idx_keywords_company_active on keywords(company_id, is_active) where is_active = true;
create index idx_keywords_priority on keywords(priority, next_discovery_at) where is_active = true;
```

**Notes**:
- Each company tracks multiple keywords for discovery
- `priority` determines discovery frequency (high = 15min, normal = 2hr, low = 6hr)
- `next_discovery_at` used by Cloud Scheduler to pick keywords due for discovery
- `total_artifacts` tracks success rate
- `max_artifacts_per_day` prevents flooding
- See **[34-SCHEDULED-DISCOVERY.md](./34-SCHEDULED-DISCOVERY.md)** for complete scheduling architecture

### Prompts
```sql
create table prompts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  body text not null,
  model text default 'gpt-5-mini',
  fine_tuned_model_id text,           -- OpenAI fine-tuned model ID (e.g., ft:gpt-5-mini:...)
  temperature numeric default 0.6,
  is_default boolean default false,
  version int default 1,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_prompts_company_id on prompts(company_id);
create index idx_prompts_company_default on prompts(company_id, is_default) where is_default = true;
create index idx_prompts_fine_tuned on prompts(company_id, fine_tuned_model_id) where fine_tuned_model_id is not null;
```

**Notes**:
- Each company can have multiple prompts
- One prompt marked `is_default` per company
- `body` contains instructions for draft composition
- `version` tracks prompt iterations
- `fine_tuned_model_id` stores company-specific fine-tuned model (if available)

---

## 3. Reddit Integration

### Company Reddit Apps
```sql
create table company_reddit_apps (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  client_id text not null,
  client_secret_ciphertext text not null,
  redirect_uri text not null,
  scopes text[] not null default '{identity,read,submit,vote}',
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_company_reddit_apps_company on company_reddit_apps(company_id);
```

**Notes**:
- One Reddit app per company
- `client_secret_ciphertext` encrypted with Cloud KMS
- `redirect_uri` must match Reddit app config exactly

### Reddit Connections (User OAuth)
```sql
create table reddit_connections (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  company_reddit_app_id uuid not null references company_reddit_apps(id) on delete cascade,
  reddit_username text,
  refresh_token_ciphertext text not null,
  expires_at timestamptz,
  scopes text[],
  karma_total int default 0,
  karma_comment int default 0,
  account_created_at timestamptz,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_reddit_connections_company on reddit_connections(company_id);
create index idx_reddit_connections_user on reddit_connections(user_id);
create index idx_reddit_connections_active on reddit_connections(company_id, is_active) where is_active = true;
```

**Notes**:
- Multiple users per company can connect Reddit accounts
- `refresh_token_ciphertext` encrypted with Cloud KMS
- Karma and account age fetched on connection
- `is_active` = false if user disconnects

---

## 4. Posting Eligibility & Volume Controls

### Posting Eligibility
```sql
create table posting_eligibility (
  company_id uuid primary key references companies(id) on delete cascade,
  min_account_age_days int default 30,
  min_total_karma int default 300,
  min_comment_karma int default 100,
  max_daily_per_sub int default 3,
  max_daily_per_account int default 10,
  max_weekly_per_account int default 70,
  cooldown_seconds int default 180,
  strict_mode boolean default false,
  updated_at timestamptz default now()
);
```

**Notes**:
- One row per company (upsert pattern)
- `strict_mode` = true enforces all checks; false = warnings only
- Enforced in `EligibilityGuard` node

---

## 5. RAG: Company Documents & Embeddings

### Company Docs
```sql
create table company_docs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  title text,
  source text,      -- "faq", "website", "notion", "upload", etc.
  url text,
  raw_text text not null,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_company_docs_company on company_docs(company_id);
create index idx_company_docs_source on company_docs(company_id, source);
```

### Company Doc Chunks (with Embeddings)
```sql
create table company_doc_chunks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  doc_id uuid not null references company_docs(id) on delete cascade,
  chunk_index int not null,
  chunk_text text not null,
  embedding vector(1536),    -- OpenAI text-embedding-3-small
  metadata jsonb,             -- {"section": "FAQ", "keywords": [...]}
  created_at timestamptz default now()
);

create index idx_company_doc_chunks_doc on company_doc_chunks(doc_id);
create index idx_company_doc_chunks_company on company_doc_chunks(company_id);
-- Vector index for similarity search
create index idx_company_doc_chunks_embedding on company_doc_chunks 
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);
```

**Notes**:
- Documents chunked into ~500-1000 tokens with overlap
- Embeddings stored as `vector(1536)` type
- `ivfflat` index for fast similarity search
- `lists` parameter tuned based on data size

---

## 6. Subreddit Discovery & History

### Subreddit History (Per Keyword)
```sql
create table subreddit_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  keyword text not null,
  subreddit text not null,
  llm_label text check (llm_label in ('good','bad')),
  llm_score numeric,
  llm_reasoning text,
  times_selected int default 0,
  times_posted int default 0,
  last_selected_at timestamptz,
  last_posted_at timestamptz,
  last_judged_at timestamptz default now(),
  created_at timestamptz default now()
);

create unique index idx_subreddit_history_unique on subreddit_history(company_id, keyword, subreddit);
create index idx_subreddit_history_keyword on subreddit_history(company_id, keyword, llm_label);
create index idx_subreddit_history_posted on subreddit_history(company_id, subreddit, last_posted_at);
```

**Notes**:
- Tracks LLM judgments per (company, keyword, subreddit)
- `llm_label='bad'` → skip in future runs for that keyword
- `times_posted` limits reuse frequency
- Updated by `JudgeSubreddit` node

---

## 7. Threads & Artifacts

### Threads
```sql
create table threads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  subreddit text not null,
  reddit_id text not null,
  title text,
  body text,
  url text,
  author text,
  created_utc timestamptz,
  score int,
  num_comments int,
  discovered_at timestamptz default now(),
  rank_score numeric,
  metadata jsonb
);

create unique index idx_threads_unique on threads(company_id, reddit_id);
create index idx_threads_subreddit on threads(company_id, subreddit, discovered_at desc);
```

### Artifacts
```sql
create table artifacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  reddit_account_id uuid references reddit_connections(id) on delete set null,
  thread_id uuid not null references threads(id) on delete cascade,
  subreddit text not null,
  keyword text not null,
  company_goal text,
  thread_reddit_id text not null,          -- Denormalized for performance
  thread_title text,
  thread_body text,
  thread_url text,
  rules_summary jsonb,                     -- {"no_links": true, "weekly_thread": false, ...}
  draft_primary text not null,
  draft_variants text[],
  rag_context jsonb,                       -- {"chunk_ids": [...], "snippets": [...]}
  judge_subreddit jsonb,                   -- {"ok": true, "score": 0.85, "reasoning": "..."}
  judge_draft jsonb,                       -- {"risk": "low", "violations": [], "suggestions": "..."}
  prompt_id uuid references prompts(id),
  status text check (status in ('new','edited','approved','posted','failed')) default 'new',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_artifacts_unique on artifacts(company_id, thread_reddit_id);
create index idx_artifacts_company_status on artifacts(company_id, status, created_at desc);
create index idx_artifacts_subreddit on artifacts(company_id, subreddit, status);
create index idx_artifacts_keyword on artifacts(company_id, keyword, status);
create index idx_artifacts_thread on artifacts(thread_id);
create index idx_artifacts_reddit_account on artifacts(reddit_account_id) where reddit_account_id is not null;
```

**Notes**:
- One artifact per (company, thread)
- `thread_id` is proper foreign key to threads table
- `reddit_account_id` set to null if account disconnected (preserves history)
- `status` tracks progression through review/approval
- `rag_context` stores retrieved company knowledge
- Both LLM judge outputs stored for transparency
- Denormalized fields (`thread_reddit_id`, `thread_title`, etc.) for performance

---

## 8. Drafts, Approvals, Posts

### Drafts
```sql
create table drafts (
  id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null references artifacts(id) on delete cascade,
  kind text check (kind in ('generated','edited')) default 'generated',
  text text not null,
  source_draft_id uuid references drafts(id),
  risk text check (risk in ('low', 'medium', 'high')),
  edit_meta jsonb,                  -- {"levenshtein": 42, "length_delta": -15, "categories": ["tone","specificity"]}
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create index idx_drafts_artifact on drafts(artifact_id, created_at desc);
create index idx_drafts_kind on drafts(artifact_id, kind);
```

**Notes**:
- Multiple versions per artifact (original + edits)
- `kind='generated'` = LLM output
- `kind='edited'` = human modified
- `source_draft_id` tracks edit chain
- `risk` stores LLM judge risk assessment
- `edit_meta` captures edit characteristics for learning

### Approvals
```sql
create table approvals (
  id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null references artifacts(id) on delete cascade,
  chosen_draft_id uuid not null references drafts(id) on delete cascade,
  approved_by uuid not null references auth.users(id),
  approved_at timestamptz default now(),
  status text check (status in ('approved','posted','failed')) default 'approved'
);

create index idx_approvals_artifact on approvals(artifact_id);
create index idx_approvals_user on approvals(approved_by, approved_at desc);
create index idx_approvals_draft on approvals(chosen_draft_id);
```

### Posts
```sql
create table posts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  reddit_account_id uuid not null references reddit_connections(id) on delete cascade,
  artifact_id uuid references artifacts(id) on delete set null,
  subreddit text not null,
  thread_reddit_id text not null,
  comment_reddit_id text,           -- Reddit's ID for the posted comment
  permalink text,
  posted_at timestamptz not null,
  verified boolean default false,
  verified_at timestamptz,
  idempotency_key text unique not null,
  retry_count int default 0,
  error_message text
);

create index idx_posts_company on posts(company_id, posted_at desc);
create index idx_posts_subreddit on posts(company_id, subreddit, posted_at desc);
create index idx_posts_account on posts(reddit_account_id, posted_at desc);
create index idx_posts_artifact on posts(artifact_id) where artifact_id is not null;
create index idx_posts_verification on posts(verified, posted_at) where verified = false;
create unique index idx_posts_idempotency on posts(idempotency_key);
```

**Notes**:
- `idempotency_key` prevents duplicate posts
- `verified` = false until visibility check passes
- `permalink` = full URL to the comment
- `reddit_account_id` cascades on delete (remove all posts if account disconnected)
- `artifact_id` set to null on delete (preserve post history even if artifact deleted)

---

## 9. Moderation & Feedback

### Moderation Events
```sql
create table moderation_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  post_id uuid not null references posts(id) on delete cascade,
  event text check (event in ('removed','shadow','automod','approved')),
  detail jsonb,                     -- {"detected_by": "verify", "reason": "..."}
  created_at timestamptz default now()
);

create index idx_moderation_events_post on moderation_events(post_id);
create index idx_moderation_events_company on moderation_events(company_id, created_at desc);
```

### Subreddit Feedback
```sql
create table subreddit_feedback (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  subreddit text not null,
  label text check (label in ('good','bad')) not null,
  reason text,
  user_id uuid not null references auth.users(id),
  created_at timestamptz default now()
);

create index idx_subreddit_feedback_company_sub on subreddit_feedback(company_id, subreddit);
```

**Notes**:
- Human feedback on subreddit fit
- Used to override or reinforce LLM judgments
- Aggregated in nightly learning jobs

---

## 10. Subreddit Accounts & Canary

### Subreddit Accounts
```sql
create table subreddit_accounts (
  id uuid primary key default gen_random_uuid(),
  reddit_account_id uuid not null references reddit_connections(id) on delete cascade,
  subreddit text not null,
  canary_passed_at timestamptz,
  canary_failed_at timestamptz,
  last_posted_at timestamptz,
  last_removed_at timestamptz,
  post_count int default 0,
  removal_count int default 0
);

create unique index idx_subreddit_accounts_unique on subreddit_accounts(reddit_account_id, subreddit);
create index idx_subreddit_accounts_canary on subreddit_accounts(reddit_account_id, canary_passed_at);
```

**Notes**:
- Tracks per-account status in each subreddit
- Canary: first post in a new subreddit; extra verification
- High removal rate → flag for review

---

## 11. Training & Learning

### Training Events
```sql
create table training_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  artifact_id uuid references artifacts(id) on delete set null,
  draft_id uuid references drafts(id) on delete set null,
  reddit_account_id uuid references reddit_connections(id) on delete set null,
  subreddit text,
  thread_reddit_id text,
  event_type text check (
    event_type in (
      'generated_draft',
      'edited_draft',
      'rejected_draft',
      'approved_draft',
      'posted',
      'removed',
      'engagement_snapshot'
    )
  ) not null,
  llm_judge jsonb,
  human_label text,
  human_reason text,
  engagement jsonb,                 -- {"score": 5, "replies": 2, "upvote_ratio": 0.85}
  created_at timestamptz default now()
);

create index idx_training_events_company on training_events(company_id, created_at desc);
create index idx_training_events_artifact on training_events(artifact_id, event_type) where artifact_id is not null;
create index idx_training_events_draft on training_events(draft_id) where draft_id is not null;
create index idx_training_events_type on training_events(event_type, created_at desc);
```

**Notes**:
- Comprehensive logging for RL/SFT
- `llm_judge` = LLM's evaluation
- `human_label` = human decision (approved/rejected/edited)
- `engagement` = post-posting metrics
- Export for training pipelines
- Segmented by `company_id` for company-specific fine-tuning
- Foreign keys set to null on delete to preserve training history

### Fine-Tuning Jobs

```sql
create table fine_tuning_jobs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  openai_job_id text,                   -- OpenAI's fine-tuning job ID
  base_model text not null,             -- e.g., 'gpt-5-mini'
  fine_tuned_model_id text,             -- Final model ID after completion
  status text check (
    status in (
      'preparing',
      'submitted',
      'running',
      'succeeded',
      'failed',
      'cancelled'
    )
  ) default 'preparing',
  training_file_id text,                -- OpenAI file ID for training data
  validation_file_id text,              -- OpenAI file ID for validation data
  num_training_examples int,
  num_validation_examples int,
  training_data_start_date timestamptz, -- Date range for training data
  training_data_end_date timestamptz,
  hyperparameters jsonb,                -- {"n_epochs": 3, "batch_size": 4, ...}
  results jsonb,                        -- Training results from OpenAI
  error_message text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  completed_at timestamptz,
  updated_at timestamptz default now()
);

create index idx_fine_tuning_jobs_company on fine_tuning_jobs(company_id, created_at desc);
create index idx_fine_tuning_jobs_status on fine_tuning_jobs(status, created_at desc);
create index idx_fine_tuning_jobs_openai on fine_tuning_jobs(openai_job_id) where openai_job_id is not null;
```

**Notes**:
- Track all fine-tuning jobs per company
- Store OpenAI job IDs for status polling
- Record training data date ranges for reproducibility
- Store hyperparameters and results for comparison
- Link completed models to `prompts.fine_tuned_model_id`

### Fine-Tuning Exports

```sql
create table fine_tuning_exports (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  export_type text check (
    export_type in ('training', 'validation', 'full')
  ) not null,
  file_path text not null,              -- S3 or local path to JSONL file
  openai_file_id text,                  -- OpenAI file ID after upload
  num_examples int not null,
  start_date timestamptz not null,      -- Date range of training_events included
  end_date timestamptz not null,
  filters jsonb,                        -- {"min_engagement_score": 5, "exclude_removed": true}
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create index idx_fine_tuning_exports_company on fine_tuning_exports(company_id, created_at desc);
create index idx_fine_tuning_exports_type on fine_tuning_exports(company_id, export_type);
```

**Notes**:
- Track all training data exports per company
- Store filters used for reproducibility
- Link to OpenAI uploaded files
- Can regenerate exports with same filters

---

## 11. Subscriptions & Billing

Stripe-based subscription management for plan limits and billing.

### Subscriptions

```sql
create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  stripe_subscription_id text unique not null,
  stripe_customer_id text not null,
  stripe_price_id text not null,
  plan_name text not null check (plan_name in ('starter', 'growth', 'enterprise')),
  status text not null check (
    status in (
      'active',
      'trialing',
      'past_due',
      'canceled',
      'unpaid',
      'incomplete',
      'incomplete_expired'
    )
  ),
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  cancel_at_period_end boolean default false,
  canceled_at timestamptz,
  trial_start timestamptz,
  trial_end timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_subscriptions_company on subscriptions(company_id);
create index idx_subscriptions_stripe_customer on subscriptions(stripe_customer_id);
create index idx_subscriptions_status on subscriptions(status);
```

### Plan Limits

```sql
create table plan_limits (
  plan_name text primary key check (plan_name in ('starter', 'growth', 'enterprise')),
  max_team_members int not null,
  max_posts_per_month int not null,
  max_reddit_accounts int not null,
  max_keywords int not null,
  fine_tuning_enabled boolean default false,
  priority_support boolean default false,
  updated_at timestamptz default now()
);

-- Insert default limits
insert into plan_limits (
  plan_name, 
  max_team_members, 
  max_posts_per_month, 
  max_reddit_accounts, 
  max_keywords,
  fine_tuning_enabled,
  priority_support
) values
  ('starter', 2, 50, 3, 2, false, false),
  ('growth', 10, 200, 10, 10, true, true),
  ('enterprise', -1, -1, -1, -1, true, true); -- -1 = unlimited
```

### Invoices

```sql
create table invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  stripe_invoice_id text unique not null,
  stripe_subscription_id text not null,
  amount_due int not null,          -- in cents
  amount_paid int not null,         -- in cents
  currency text default 'usd',
  status text not null check (
    status in ('draft', 'open', 'paid', 'uncollectible', 'void')
  ),
  invoice_pdf text,                 -- URL to PDF
  hosted_invoice_url text,          -- Stripe hosted page
  period_start timestamptz not null,
  period_end timestamptz not null,
  due_date timestamptz,
  paid_at timestamptz,
  created_at timestamptz default now()
);

create index idx_invoices_company on invoices(company_id);
create index idx_invoices_stripe_subscription on invoices(stripe_subscription_id);
```

**Notes**:
- Subscriptions managed via Stripe webhooks
- Plan limits enforced in backend logic
- Invoice history for customer records
- See **26-PRICING-BILLING.md** for complete implementation

---

## 12. LangGraph State Persistence

LangGraph requires database-backed state persistence for:
- Stateless Cloud Run deployments
- Resume workflows after crashes
- Multi-instance deployments
- Debugging and replay

### LangGraph Checkpointer Tables

```sql
-- LangGraph checkpoint storage
create table langgraph_checkpoints (
  thread_id text not null,
  checkpoint_ns text not null default '',
  checkpoint_id text not null,
  parent_checkpoint_id text,
  type text,
  checkpoint jsonb not null,
  metadata jsonb not null default '{}'::jsonb,
  primary key (thread_id, checkpoint_ns, checkpoint_id)
);

create index idx_langgraph_checkpoints_parent 
  on langgraph_checkpoints(thread_id, checkpoint_ns, parent_checkpoint_id);

-- LangGraph checkpoint writes (for tracking modifications)
create table langgraph_checkpoint_writes (
  thread_id text not null,
  checkpoint_ns text not null default '',
  checkpoint_id text not null,
  task_id text not null,
  idx integer not null,
  channel text not null,
  type text,
  value jsonb,
  primary key (thread_id, checkpoint_ns, checkpoint_id, task_id, idx)
);

create index idx_langgraph_writes_checkpoint 
  on langgraph_checkpoint_writes(thread_id, checkpoint_ns, checkpoint_id);
```

**Notes**:
- These tables follow LangGraph's PostgresCheckpointer schema
- `thread_id` = unique identifier for each generation run (e.g., `company_id:artifact_id`)
- `checkpoint_id` = state snapshot at each node
- `checkpoint` = serialized graph state (JSONB)
- Enables resume from any point in the workflow
- No RLS needed (backend-only access with service role)

---

## 13. Row Level Security (RLS)

Enable RLS on all company-scoped tables:

```sql
-- Enable RLS
alter table companies enable row level security;
alter table user_profiles enable row level security;
alter table keywords enable row level security;
alter table prompts enable row level security;
alter table company_reddit_apps enable row level security;
alter table reddit_connections enable row level security;
alter table posting_eligibility enable row level security;
alter table company_docs enable row level security;
alter table company_doc_chunks enable row level security;
alter table subreddit_history enable row level security;
alter table threads enable row level security;
alter table artifacts enable row level security;
alter table drafts enable row level security;
alter table approvals enable row level security;
alter table posts enable row level security;
alter table moderation_events enable row level security;
alter table subreddit_feedback enable row level security;
alter table subreddit_accounts enable row level security;
alter table training_events enable row level security;
alter table fine_tuning_jobs enable row level security;
alter table fine_tuning_exports enable row level security;
alter table subscriptions enable row level security;
alter table invoices enable row level security;

-- Helper function to get user's company_id from JWT
create or replace function auth.user_company_id()
returns uuid
language sql
stable
as $$
  select company_id from user_profiles where id = auth.uid()
$$;

-- Example policy for prompts table
create policy "Users can view their company's prompts"
  on prompts for select
  using (company_id = auth.user_company_id());

create policy "Admins can insert prompts"
  on prompts for insert
  with check (
    company_id = auth.user_company_id() 
    and exists (
      select 1 from user_profiles 
      where id = auth.uid() 
      and role in ('owner', 'admin')
    )
  );

-- Similar policies for all other tables...
```

**Implementation**:
- Apply policies in **M5-PRODUCTION.md**
- Backend uses service role key (bypasses RLS)
- Frontend uses user JWT (enforces RLS)

---

## 14. Useful Queries

### Recent artifacts needing review
```sql
select 
  a.id,
  a.subreddit,
  a.keyword,
  t.title as thread_title,
  a.status,
  a.created_at
from artifacts a
join threads t on t.id = a.thread_id
where a.company_id = :company_id
  and a.status = 'new'
order by a.created_at desc
limit 20;
```

### Posting volume by account (last 7 days)
```sql
select 
  rc.reddit_username,
  count(*) as post_count,
  count(*) filter (where p.posted_at > now() - interval '1 day') as today,
  count(*) filter (where p.verified = false) as unverified
from posts p
join reddit_connections rc on rc.id = p.reddit_account_id
where p.company_id = :company_id
  and p.posted_at > now() - interval '7 days'
group by rc.reddit_username
order by post_count desc;
```

### Subreddits marked bad for a keyword
```sql
select 
  subreddit,
  llm_score,
  llm_reasoning,
  last_judged_at
from subreddit_history
where company_id = :company_id
  and keyword = :keyword
  and llm_label = 'bad'
order by last_judged_at desc;
```

### RAG similarity search
```sql
select 
  cdc.id,
  cd.title as doc_title,
  cdc.chunk_text,
  1 - (cdc.embedding <=> :query_vector::vector) as similarity
from company_doc_chunks cdc
join company_docs cd on cd.id = cdc.doc_id
where cdc.company_id = :company_id
order by cdc.embedding <=> :query_vector::vector
limit 5;
```

---

## Next Steps
1. Run all migrations in order
2. Verify extensions are enabled
3. Insert test data for development
4. Proceed to **M1-FOUNDATIONS.md**

