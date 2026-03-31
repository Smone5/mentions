# RL & Fine-Tuning Data Collection

Strategy for collecting training data to improve model performance over time.

---

## Training Events

Log all user interactions for future fine-tuning:

```sql
create table training_events (
  id uuid primary key,
  draft_id uuid references drafts(id),
  post_id uuid references posts(id),
  event_type text check (event_type in (
    'draft_approved',
    'draft_rejected',
    'draft_edited',
    'post_created',
    'post_verified',
    'post_removed'
  )),
  user_id uuid references auth.users(id),
  data jsonb,
  created_at timestamptz default now()
);
```

---

## Event Types

### 1. Draft Approved
**Signal**: User likes this draft  
**Use**: Positive training example

### 2. Draft Rejected
**Signal**: User doesn't like this draft  
**Use**: Negative training example, learn what to avoid

### 3. Draft Edited
**Signal**: User modified the draft  
**Data**: `{old_body, new_body}`  
**Use**: Learn preferred writing style

### 4. Post Verified
**Signal**: Post survived Reddit's filters  
**Use**: Positive training example (passed all checks)

### 5. Post Removed
**Signal**: Post was removed or flagged  
**Use**: Negative training example (learn what triggered removal)

---

## Export for Fine-Tuning

See complete implementation in [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md), Task 4.4.

```python
# services/fine_tuning.py
async def export_training_data(company_id, start_date, end_date):
    """
    Export training data in OpenAI JSONL format:
    {"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
    """
    drafts = await fetch_approved_drafts(company_id, start_date, end_date)
    
    training_examples = []
    for draft in drafts:
        training_examples.append({
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": format_input(draft)},
                {"role": "assistant", "content": draft.body}
            ]
        })
    
    # Save as JSONL
    with open(f"training_{company_id}.jsonl", 'w') as f:
        for example in training_examples:
            f.write(json.dumps(example) + '\n')
    
    return export_id
```

---

## Fine-Tuning Jobs

Track company-specific fine-tuning jobs:

```sql
create table fine_tuning_jobs (
  id uuid primary key,
  company_id uuid references companies(id),
  openai_job_id text,
  base_model text,
  fine_tuned_model_id text,
  status text,
  num_training_examples int,
  created_at timestamptz default now()
);
```

---

## Feedback Loop

```
Drafts Generated → Human Approval/Rejection → Logged as Training Events 
→ Monthly Export → Fine-Tune Company Model → Use Fine-Tuned Model → Better Drafts
```

---

## RLHF (Future)

**Reinforcement Learning from Human Feedback**:
1. Collect preference data (A vs B)
2. Train reward model
3. Use PPO to optimize policy
4. Deploy improved model

**Signals for reward model**:
- Approval rate
- Edit distance
- Post verification success
- Time to approval

---

## Company-Specific Models

See [19-COMPANY-FINE-TUNING.md](./19-COMPANY-FINE-TUNING.md) for complete strategy.

Each company gets their own fine-tuned model:
- Trained on their approved drafts
- Learns their tone and style
- Uses their domain knowledge

---

## Verification

- [ ] All events logged correctly
- [ ] Export produces valid JSONL
- [ ] Can upload to OpenAI for fine-tuning
- [ ] Fine-tuned models improve approval rate

**Reference**: [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md), [19-COMPANY-FINE-TUNING.md](./19-COMPANY-FINE-TUNING.md)






