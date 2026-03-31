# Company-Specific Fine-Tuning

## Overview
Each company can fine-tune GPT-5-mini on their own training data to create a custom model that learns their specific writing style, tone, domain knowledge, and quality standards.

**Why Company-Specific Models?**
- **Unique voice**: Each company has distinct brand voice and communication style
- **Domain expertise**: Company-specific terminology and context
- **Quality preferences**: What one company considers high-quality may differ
- **Approval patterns**: Learn from what humans approve vs reject

---

## Architecture

### Data Flow

```
Training Events (segmented by company_id)
           ↓
    Export to JSONL
           ↓
    Upload to OpenAI
           ↓
    Fine-Tuning Job
           ↓
    Fine-Tuned Model ID
           ↓
    Link to Company Prompt
           ↓
    Use in Draft Generation
```

### Database Tables

**1. `training_events`**
- All events logged with `company_id`
- Includes: generated drafts, edits, approvals, rejections, engagement

**2. `fine_tuning_jobs`**
- Track fine-tuning job status per company
- Store OpenAI job IDs and results

**3. `fine_tuning_exports`**
- Track training data exports
- Store filters for reproducibility

**4. `prompts`**
- `fine_tuned_model_id` field links to company's custom model
- Falls back to base `gpt-5-mini` if no fine-tuned model

---

## Training Data Format

### OpenAI Fine-Tuning Format (JSONL)

Each line is a JSON object with `messages` array:

```json
{
  "messages": [
    {
      "role": "system",
      "content": "You are drafting a helpful reply for r/ProgrammingHelp. Company goal: Help developers solve coding problems. Rules: No links, be helpful and specific."
    },
    {
      "role": "user",
      "content": "Thread title: How do I fix 'cannot import name' error in Python?\nThread body: I'm getting an ImportError when trying to import a function from another file. My project structure is: project/main.py and project/utils.py\n\nCompany knowledge: Our Python best practices guide recommends using absolute imports and checking for circular dependencies."
    },
    {
      "role": "assistant",
      "content": "This error usually happens due to circular imports or incorrect import paths. Since you have a simple two-file structure, try these steps:\n\n1. Make sure you have an `__init__.py` file in your project folder to make it a package\n2. Use absolute imports like `from project.utils import function_name`\n3. Check if utils.py is trying to import from main.py - that would create a circular dependency\n\nAlso, verify that the function you're importing is actually defined in utils.py and isn't misspelled. Python is case-sensitive!"
    }
  ]
}
```

### Data Sources for Training Examples

**Supervised Fine-Tuning (SFT):**
1. **Approved drafts** (`event_type='approved_draft'`)
   - LLM's generated draft → Human's final approved version
   
2. **Edited drafts** (`event_type='edited_draft'`)
   - Original draft → Human's edited version
   - Learn from edit patterns

3. **High-engagement posts** (`event_type='posted'` with `engagement.score > threshold`)
   - Posts that performed well
   - Positive reinforcement

**Negative Examples (Optional):**
4. **Rejected drafts** (`event_type='rejected_draft'`)
   - Can be used with preference learning (DPO/RLHF)
   - Show what NOT to do

5. **Removed posts** (`event_type='removed'`)
   - Learn from moderation failures
   - Avoid similar mistakes

---

## Export Process

### Step 1: Query Training Events

```sql
-- Export approved/edited drafts for company
select
  te.id,
  te.artifact_id,
  ra.subreddit,
  ra.keyword,
  ra.company_goal,
  ra.rules_summary,
  ra.rag_context,
  t.title as thread_title,
  t.body as thread_body,
  -- Original LLM draft
  (select text from draft_versions 
   where artifact_id = ra.id 
   and kind = 'generated' 
   order by created_at asc 
   limit 1) as original_draft,
  -- Final approved/edited version
  (select text from draft_versions dv
   join approvals a on a.chosen_version_id = dv.id
   where dv.artifact_id = ra.id
   order by a.approved_at desc
   limit 1) as final_draft,
  te.engagement,
  te.created_at
from training_events te
join ready_artifacts ra on ra.id = te.artifact_id
join threads t on t.reddit_id = ra.thread_reddit_id
where te.company_id = :company_id
  and te.event_type in ('approved_draft', 'edited_draft')
  and te.created_at between :start_date and :end_date
  and (
    -- High engagement filter
    (te.engagement->>'score')::int >= 3
    or te.event_type = 'edited_draft'
  )
order by te.created_at asc;
```

### Step 2: Format as JSONL

```python
def format_training_example(row):
    """Convert training event to OpenAI fine-tuning format."""
    
    # Build system prompt
    system_content = f"""You are drafting a helpful reply for r/{row['subreddit']}.

Company goal: {row['company_goal']}

Subreddit rules:
{format_rules(row['rules_summary'])}"""
    
    # Build user prompt (context)
    user_content = f"""Thread title: {row['thread_title']}
Thread body: {row['thread_body']}

Company knowledge:
{format_rag_context(row['rag_context'])}

Draft a helpful, natural reply. Do NOT include any links."""
    
    # Assistant response (final approved version)
    assistant_content = row['final_draft']
    
    return {
        "messages": [
            {"role": "system", "content": system_content},
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": assistant_content}
        ]
    }
```

### Step 3: Split Train/Validation

```python
def export_training_data(
    company_id: str,
    start_date: datetime,
    end_date: datetime,
    min_engagement_score: int = 3,
    validation_split: float = 0.1
):
    """Export training data for fine-tuning."""
    
    # Query training events
    rows = query_training_events(
        company_id,
        start_date,
        end_date,
        min_engagement_score
    )
    
    # Format as JSONL
    examples = [format_training_example(row) for row in rows]
    
    # Shuffle and split
    random.shuffle(examples)
    split_idx = int(len(examples) * (1 - validation_split))
    train_examples = examples[:split_idx]
    val_examples = examples[split_idx:]
    
    # Write JSONL files
    train_path = f"exports/{company_id}_train_{start_date}_{end_date}.jsonl"
    val_path = f"exports/{company_id}_val_{start_date}_{end_date}.jsonl"
    
    write_jsonl(train_path, train_examples)
    write_jsonl(val_path, val_examples)
    
    # Save export record
    save_export_record(
        company_id=company_id,
        export_type='training',
        file_path=train_path,
        num_examples=len(train_examples),
        start_date=start_date,
        end_date=end_date
    )
    
    return train_path, val_path
```

---

## Fine-Tuning Job Creation

### Step 1: Upload Training Files to OpenAI

```python
import openai
from openai import OpenAI

async def upload_training_files(
    company_id: str,
    train_file_path: str,
    val_file_path: str
) -> tuple[str, str]:
    """Upload training and validation files to OpenAI."""
    
    client = OpenAI(api_key=settings.openai_api_key)
    
    # Upload training file
    with open(train_file_path, 'rb') as f:
        train_file = client.files.create(
            file=f,
            purpose='fine-tune'
        )
    
    # Upload validation file
    with open(val_file_path, 'rb') as f:
        val_file = client.files.create(
            file=f,
            purpose='fine-tune'
        )
    
    return train_file.id, val_file.id
```

### Step 2: Create Fine-Tuning Job

```python
async def create_fine_tuning_job(
    company_id: str,
    train_file_id: str,
    val_file_id: str,
    base_model: str = 'gpt-5-mini',
    n_epochs: int = 3,
    suffix: str = None
) -> str:
    """Create OpenAI fine-tuning job."""
    
    client = OpenAI(api_key=settings.openai_api_key)
    
    # Generate suffix if not provided
    if not suffix:
        company_name = get_company_name(company_id)
        suffix = f"{company_name}-{datetime.now().strftime('%Y%m%d')}"[:40]
    
    # Create job
    job = client.fine_tuning.jobs.create(
        training_file=train_file_id,
        validation_file=val_file_id,
        model=base_model,
        suffix=suffix,
        hyperparameters={
            "n_epochs": n_epochs,
            "batch_size": "auto",
            "learning_rate_multiplier": "auto"
        }
    )
    
    # Save job record
    await db.execute(
        """
        insert into fine_tuning_jobs (
            company_id, openai_job_id, base_model, status,
            training_file_id, validation_file_id,
            hyperparameters, created_at
        ) values ($1, $2, $3, $4, $5, $6, $7, now())
        """,
        company_id,
        job.id,
        base_model,
        'submitted',
        train_file_id,
        val_file_id,
        json.dumps({"n_epochs": n_epochs})
    )
    
    return job.id
```

### Step 3: Poll Job Status

```python
async def poll_fine_tuning_job(job_id: str):
    """Poll OpenAI for fine-tuning job status."""
    
    client = OpenAI(api_key=settings.openai_api_key)
    
    job = client.fine_tuning.jobs.retrieve(job_id)
    
    # Update database
    await db.execute(
        """
        update fine_tuning_jobs
        set status = $1,
            fine_tuned_model_id = $2,
            results = $3,
            error_message = $4,
            completed_at = $5,
            updated_at = now()
        where openai_job_id = $6
        """,
        job.status,
        job.fine_tuned_model,
        json.dumps({
            "trained_tokens": job.trained_tokens,
            "result_files": job.result_files
        }),
        job.error.message if job.error else None,
        datetime.fromtimestamp(job.finished_at) if job.finished_at else None,
        job_id
    )
    
    # If succeeded, link to prompt
    if job.status == 'succeeded' and job.fine_tuned_model:
        await link_model_to_prompt(
            job_id=job_id,
            fine_tuned_model_id=job.fine_tuned_model
        )
    
    return job.status
```

---

## Using Fine-Tuned Models

### Draft Generation with Company Model

```python
async def draft_compose(state: Dict[str, Any]) -> Dict[str, Any]:
    """Compose draft using company's fine-tuned model if available."""
    
    # Get company prompt
    prompt_row = await db.fetchone(
        """
        select 
            body, 
            model, 
            fine_tuned_model_id, 
            temperature 
        from prompts 
        where id = $1
        """,
        state['prompt_id']
    )
    
    # Use fine-tuned model if available, otherwise base model
    model = prompt_row['fine_tuned_model_id'] or prompt_row['model']
    
    # Build context
    thread = state['thread']
    rag_snippets = state['rag_context']['snippets']
    rules = state['subreddit_rules']
    
    # System prompt (company instructions)
    system_prompt = f"""You are drafting a helpful reply for r/{state['subreddit_candidate']['name']}.

{prompt_row['body']}

Subreddit Rules:
{format_rules(rules)}"""
    
    # User prompt (context)
    user_prompt = f"""Thread title: {thread['title']}
Thread body: {thread['body']}

Company knowledge:
{format_rag_snippets(rag_snippets)}

Draft a helpful, natural reply. Do NOT include any links."""
    
    # Call LLM with fine-tuned model
    llm = ChatOpenAI(
        model=model,  # Will be fine-tuned model ID if available
        temperature=prompt_row['temperature']
    )
    
    result = await llm.ainvoke([
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ])
    
    draft_text = result.content.strip()
    
    return {
        "draft": {
            "text": draft_text,
            "model_used": model,
            "is_fine_tuned": bool(prompt_row['fine_tuned_model_id']),
            "variants": [],
            "risk": "unknown"
        }
    }
```

---

## API Endpoints

### POST /api/fine-tuning/export

Export training data for a company.

**Request:**
```json
{
  "company_id": "uuid",
  "start_date": "2025-01-01T00:00:00Z",
  "end_date": "2025-11-01T00:00:00Z",
  "min_engagement_score": 3,
  "exclude_removed": true,
  "validation_split": 0.1
}
```

**Response:**
```json
{
  "export_id": "uuid",
  "train_file_path": "exports/company_train.jsonl",
  "val_file_path": "exports/company_val.jsonl",
  "num_train_examples": 850,
  "num_val_examples": 95
}
```

### POST /api/fine-tuning/jobs

Create a new fine-tuning job.

**Request:**
```json
{
  "company_id": "uuid",
  "export_id": "uuid",
  "base_model": "gpt-5-mini",
  "n_epochs": 3,
  "suffix": "acme-2025"
}
```

**Response:**
```json
{
  "job_id": "uuid",
  "openai_job_id": "ftjob-abc123",
  "status": "submitted",
  "estimated_completion": "2025-11-06T12:00:00Z"
}
```

### GET /api/fine-tuning/jobs/{job_id}

Get fine-tuning job status.

**Response:**
```json
{
  "job_id": "uuid",
  "openai_job_id": "ftjob-abc123",
  "company_id": "uuid",
  "status": "running",
  "base_model": "gpt-5-mini",
  "fine_tuned_model_id": null,
  "num_training_examples": 850,
  "progress": 0.45,
  "created_at": "2025-11-05T10:00:00Z",
  "estimated_completion": "2025-11-06T12:00:00Z"
}
```

### GET /api/fine-tuning/jobs

List all fine-tuning jobs for a company.

**Query Params:**
- `company_id` (required)
- `status` (optional): filter by status
- `limit` (default: 25)
- `offset` (default: 0)

### POST /api/prompts/{prompt_id}/link-model

Link a fine-tuned model to a prompt.

**Request:**
```json
{
  "fine_tuned_model_id": "ft:gpt-5-mini:acme:20251105"
}
```

**Response:**
```json
{
  "prompt_id": "uuid",
  "fine_tuned_model_id": "ft:gpt-5-mini:acme:20251105",
  "updated_at": "2025-11-06T12:00:00Z"
}
```

---

## Minimum Data Requirements

### Recommended Minimums
- **100+ approved/edited drafts** for initial fine-tune
- **500+ examples** for good performance
- **1000+ examples** for best results

### Data Quality Over Quantity
- Prefer high-engagement posts (score ≥ 5)
- Include diverse subreddits and topics
- Balance different types of edits
- Remove duplicates and near-duplicates

### Validation Set
- 10-20% of data held out for validation
- Helps prevent overfitting
- Provides metrics for model evaluation

---

## Monitoring & Iteration

### Track Model Performance

```sql
-- Compare fine-tuned vs base model performance
select
  case when ra.prompt_id in (
    select id from prompts where fine_tuned_model_id is not null
  ) then 'fine-tuned' else 'base' end as model_type,
  count(*) as total_drafts,
  count(*) filter (where te.event_type = 'approved_draft') as approved,
  count(*) filter (where te.event_type = 'rejected_draft') as rejected,
  count(*) filter (where te.event_type = 'edited_draft') as edited,
  avg((te.engagement->>'score')::int) filter (where te.event_type = 'posted') as avg_score
from training_events te
join ready_artifacts ra on ra.id = te.artifact_id
where te.company_id = :company_id
  and te.created_at > :model_deployment_date
group by model_type;
```

### A/B Testing
- Run base model and fine-tuned model side-by-side
- Randomly assign 50% of requests to each
- Compare approval rates, edit frequency, engagement
- Decide whether to deploy fine-tuned model

### Continuous Improvement
- Retrain monthly with new data
- Include recent high-performing posts
- Adjust hyperparameters based on results
- Track version performance over time

---

## Cost Considerations

### OpenAI Fine-Tuning Costs
- **Training**: ~$0.008 per 1K tokens
- **Inference**: ~2-4x base model cost
- **Storage**: Minimal

### Budget Example
- 1000 examples × 500 tokens avg = 500K tokens
- Training cost: ~$4 per fine-tune
- 10K inferences/month: ~$20-40/month additional

### When to Fine-Tune
- **Wait until**: 500+ quality examples collected
- **Retrain when**: 
  - Performance degrades
  - Significant style change
  - Quarterly updates with new data
- **Don't fine-tune if**: 
  - < 100 examples
  - High turnover in approval team
  - Inconsistent feedback

---

## Security & Privacy

### Data Isolation
- All training data filtered by `company_id`
- RLS prevents cross-company data leakage
- Fine-tuned models are company-specific

### PII Handling
- Strip usernames from training data (except in metadata)
- Remove any personal information from thread context
- OpenAI's data processing agreement applies

### Model Access
- Fine-tuned models only accessible via company's API key
- Not shared between companies
- Can be deleted on request

---

## Next Steps

1. **M4**: Implement training data export endpoints
2. **M5**: Build fine-tuning job management UI
3. **Post-Launch**: Collect 100+ examples per company
4. **Month 2**: Start first fine-tuning experiments
5. **Month 3**: Deploy fine-tuned models for early adopters
6. **Ongoing**: Monitor performance and iterate

---

## References
- [OpenAI Fine-Tuning Guide](https://platform.openai.com/docs/guides/fine-tuning)
- [GPT-5 Fine-Tuning Best Practices](https://platform.openai.com/docs/guides/fine-tuning/advanced-usage)
- Training Events Schema: **03-DATABASE-SCHEMA.md** (Section 11)
- RL/SFT Logging: **16-RL-FINE-TUNING.md**






