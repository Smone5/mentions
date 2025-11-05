# Milestone 2: Generation Flow

## Goal
Implement LangGraph pipeline for subreddit discovery, gating with LLM judges, RAG retrieval, draft composition, and artifact creation.

**Timeline**: Weeks 3-4  
**Depends On**: M1 complete  
**Outputs**: System generates ReadyForReview artifacts with drafts grounded in company data

---

## Acceptance Criteria

- [ ] For a given keyword, system searches Reddit for candidate subreddits
- [ ] LLM JudgeSubreddit acts as hard gate (bad subreddits skipped)
- [ ] Subreddit history prevents reuse of bad subreddits
- [ ] System fetches subreddit rules and summarizes them
- [ ] System finds good threads (questions/help posts)
- [ ] RAG retrieves relevant company knowledge
- [ ] System drafts multiple reply variants
- [ ] LLM JudgeDraft evaluates quality before surfacing
- [ ] ReadyForReview artifacts created with all context
- [ ] Bad drafts regenerated or rejected (not surfaced)

---

## Architecture Overview

```
┌─────────────────────────┐
│  Input: keyword, goal   │
└────────────┬────────────┘
             │
             ▼
    ┌────────────────────┐
    │ FetchSubreddits    │ ← Reddit search
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ ApplyHistoryFilter │ ← Skip known bad
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ JudgeSubreddit     │ ← LLM hard gate
    └────────┬───────────┘
             │ (if ok=true)
             ▼
    ┌────────────────────┐
    │ FetchRules         │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ FetchThreads       │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ RankThreads        │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ RAGRetrieve        │ ← pgvector search
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ DraftCompose       │ ← LLM with context
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ VaryDraft          │ ← Paraphrase 2-3x
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ JudgeDraft         │ ← LLM quality gate
    └────────┬───────────┘
             │ (if acceptable)
             ▼
    ┌────────────────────┐
    │ EmitReadyForReview │
    └────────────────────┘
```

---

## Tasks

### 2.1 LangGraph Setup

**Install Dependencies**:
```bash
pip install langgraph langchain-core langchain-openai asyncpraw
```

**Structure**:
```
graph/
├── state.py           # State definition
├── build.py           # Graph construction
└── nodes/
    ├── fetch_subreddits.py
    ├── judge_subreddit.py
    ├── fetch_rules.py
    ├── fetch_threads.py
    ├── rank_threads.py
    ├── rag_retrieve.py
    ├── draft_compose.py
    ├── vary_draft.py
    ├── judge_draft.py
    └── emit_ready.py
```

**State Definition** (`graph/state.py`):
```python
from typing import TypedDict, Optional, List, Dict, Any

class GenerateState(TypedDict):
    # Input
    company_id: str
    user_id: str
    company_goal: str
    keywords: List[str]
    keyword: str              # Active keyword for this run
    reddit_account_id: str
    prompt_id: str
    
    # Subreddit discovery
    subreddit_candidates: List[Dict[str, Any]]
    subreddit_candidate: Dict[str, Any]  # Current candidate
    subreddit_rules: Dict[str, Any]
    
    # Thread selection
    threads: List[Dict[str, Any]]
    thread: Dict[str, Any]
    
    # RAG
    rag_context: Dict[str, Any]  # {"chunk_ids": [...], "snippets": [...]}
    
    # Draft
    draft: Dict[str, Any]  # {"text": str, "variants": List[str], "risk": str}
    
    # Judgments
    judgments: Dict[str, Any]  # {"subreddit": {...}, "draft": {...}}
    
    # Control
    error: Optional[str]
    retry_count: int
```

- [ ] Create state definition
- [ ] Set up basic graph structure
- [ ] Add error handling and retries

---

### 2.2 Node: FetchSubreddits

**Purpose**: Search Reddit for candidate subreddits matching keyword

**Implementation** (`graph/nodes/fetch_subreddits.py`):
```python
from typing import Dict, Any
import asyncpraw
from core.config import settings

async def fetch_subreddits(state: Dict[str, Any]) -> Dict[str, Any]:
    """Search Reddit for subreddits matching keyword."""
    keyword = state['keyword']
    
    # Use Reddit search API
    async with asyncpraw.Reddit(
        client_id=...,  # From company's Reddit app
        client_secret=...,  # Decrypt from DB
        user_agent="mentions/1.0"
    ) as reddit:
        # Search subreddits
        subreddits = []
        async for subreddit in reddit.subreddits.search(keyword, limit=20):
            subreddits.append({
                "name": subreddit.display_name,
                "title": subreddit.title,
                "description": subreddit.public_description,
                "subscribers": subreddit.subscribers,
                "active_users": getattr(subreddit, 'active_user_count', 0),
                "over18": subreddit.over18
            })
    
    return {"subreddit_candidates": subreddits}
```

**Tasks**:
- [ ] Implement Reddit search
- [ ] Fetch subreddit metadata (subscribers, activity, etc.)
- [ ] Sort by relevance/size
- [ ] Handle rate limits

---

### 2.3 Node: ApplyHistoryFilter

**Purpose**: Filter out subreddits previously judged as bad for this keyword

**Implementation**:
```python
async def apply_history_filter(state: Dict[str, Any]) -> Dict[str, Any]:
    """Remove subreddits with llm_label='bad' for this keyword."""
    company_id = state['company_id']
    keyword = state['keyword']
    candidates = state['subreddit_candidates']
    
    # Query subreddit_history
    bad_subs = await db.fetch(
        """
        select subreddit from subreddit_history
        where company_id = %s and keyword = %s and llm_label = 'bad'
        """,
        company_id, keyword
    )
    bad_sub_names = {row['subreddit'] for row in bad_subs}
    
    # Also check if we've posted too many times recently
    overused_subs = await db.fetch(
        """
        select subreddit from subreddit_history
        where company_id = %s 
          and keyword = %s
          and times_posted >= 5
          and last_posted_at > now() - interval '30 days'
        """,
        company_id, keyword
    )
    overused_sub_names = {row['subreddit'] for row in overused_subs}
    
    # Filter candidates
    filtered = [
        sub for sub in candidates
        if sub['name'] not in bad_sub_names 
        and sub['name'] not in overused_sub_names
    ]
    
    return {"subreddit_candidates": filtered}
```

- [ ] Implement history lookup
- [ ] Filter bad subreddits
- [ ] Filter overused subreddits
- [ ] Log filtered count

---

### 2.4 Node: JudgeSubreddit (LLM Hard Gate)

**Purpose**: Use LLM to evaluate if subreddit is a good fit; skip if not

**Implementation**:
```python
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate

async def judge_subreddit(state: Dict[str, Any]) -> Dict[str, Any]:
    """LLM judges if subreddit is good fit. HARD GATE."""
    
    # Iterate through candidates
    for candidate in state['subreddit_candidates']:
        subreddit = candidate['name']
        
        # Build prompt
        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are evaluating if a subreddit is appropriate for posting helpful replies.

Company Goal: {company_goal}
Keyword: {keyword}

Subreddit: r/{subreddit}
Title: {title}
Description: {description}
Subscribers: {subscribers}

Evaluate:
1. Is this subreddit relevant to the keyword and company goal?
2. Does it allow helpful, informative comments?
3. Is it a legitimate community (not spam/NSFW/banned)?

Respond in JSON:
{{
  "ok": true/false,
  "score": 0.0-1.0,
  "reasoning": "brief explanation"
}}
"""),
            ("user", "Evaluate this subreddit.")
        ])
        
        llm = ChatOpenAI(model="gpt-5-mini", temperature=0.2)
        
        result = await llm.ainvoke(
            prompt.format_messages(
                company_goal=state['company_goal'],
                keyword=state['keyword'],
                subreddit=subreddit,
                title=candidate['title'],
                description=candidate['description'],
                subscribers=candidate['subscribers']
            )
        )
        
        judgment = parse_json(result.content)
        
        # Save to subreddit_history
        await db.execute(
            """
            insert into subreddit_history (
                company_id, keyword, subreddit, llm_label, llm_score, 
                llm_reasoning, last_judged_at
            ) values (%s, %s, %s, %s, %s, %s, now())
            on conflict (company_id, keyword, subreddit) do update set
                llm_label = excluded.llm_label,
                llm_score = excluded.llm_score,
                llm_reasoning = excluded.llm_reasoning,
                last_judged_at = now()
            """,
            state['company_id'],
            state['keyword'],
            subreddit,
            'good' if judgment['ok'] else 'bad',
            judgment['score'],
            judgment['reasoning']
        )
        
        # If OK, select this subreddit and continue
        if judgment['ok']:
            await db.execute(
                """
                update subreddit_history
                set times_selected = times_selected + 1,
                    last_selected_at = now()
                where company_id = %s and keyword = %s and subreddit = %s
                """,
                state['company_id'], state['keyword'], subreddit
            )
            
            return {
                "subreddit_candidate": candidate,
                "judgments": {
                    **state.get('judgments', {}),
                    "subreddit": judgment
                }
            }
    
    # No good subreddit found
    return {"error": "No suitable subreddit found"}
```

**Tasks**:
- [ ] Implement LLM prompt for subreddit evaluation
- [ ] Parse JSON response
- [ ] Save to `subreddit_history`
- [ ] Implement hard gate logic (first "ok" wins)
- [ ] Handle case where no subreddit passes

---

### 2.5 Node: FetchRules

**Purpose**: Get subreddit rules and summarize for draft composition

**Implementation**:
```python
async def fetch_rules(state: Dict[str, Any]) -> Dict[str, Any]:
    """Fetch and summarize subreddit rules."""
    subreddit_name = state['subreddit_candidate']['name']
    
    async with asyncpraw.Reddit(...) as reddit:
        subreddit = await reddit.subreddit(subreddit_name)
        
        # Get rules
        rules = []
        async for rule in subreddit.rules:
            rules.append({
                "short_name": rule.short_name,
                "description": rule.description,
                "kind": rule.kind  # "link", "comment", "all"
            })
        
        # Get wiki/sidebar (if accessible)
        try:
            sidebar = subreddit.description
        except:
            sidebar = None
    
    # Summarize with LLM
    llm = ChatOpenAI(model="gpt-5-mini", temperature=0.2)
    summary_prompt = f"""Summarize the key rules for posting comments in r/{subreddit_name}.

Rules:
{rules}

Sidebar:
{sidebar}

Extract:
1. no_links: true/false
2. no_self_promo: true/false
3. weekly_thread_only: true/false
4. tone_requirements: "helpful", "casual", etc.
5. other_restrictions: brief list

Respond in JSON."""
    
    summary_result = await llm.ainvoke(summary_prompt)
    rules_summary = parse_json(summary_result.content)
    
    return {"subreddit_rules": rules_summary}
```

- [ ] Fetch subreddit rules via API
- [ ] Fetch sidebar/wiki if available
- [ ] Summarize with LLM
- [ ] Store in structured format

---

### 2.6 Node: FetchThreads

**Purpose**: Find recent threads suitable for helpful replies

**Implementation**:
```python
async def fetch_threads(state: Dict[str, Any]) -> Dict[str, Any]:
    """Fetch recent threads (questions, help posts)."""
    subreddit_name = state['subreddit_candidate']['name']
    keyword = state['keyword']
    
    async with asyncpraw.Reddit(...) as reddit:
        subreddit = await reddit.subreddit(subreddit_name)
        
        threads = []
        
        # Search for keyword in recent posts
        async for submission in subreddit.search(
            keyword, 
            sort='new', 
            time_filter='week',
            limit=50
        ):
            # Filter for question/help posts
            if is_question_or_help_post(submission):
                threads.append({
                    "reddit_id": submission.id,
                    "title": submission.title,
                    "body": submission.selftext,
                    "author": submission.author.name if submission.author else "[deleted]",
                    "created_utc": submission.created_utc,
                    "score": submission.score,
                    "num_comments": submission.num_comments,
                    "url": submission.url
                })
        
        # Also check for weekly threads
        async for submission in subreddit.hot(limit=10):
            if "weekly" in submission.title.lower() or "megathread" in submission.title.lower():
                threads.append(...)  # Add weekly thread
    
    return {"threads": threads}

def is_question_or_help_post(submission) -> bool:
    """Heuristic to identify question posts."""
    title_lower = submission.title.lower()
    return (
        '?' in submission.title
        or any(word in title_lower for word in ['how', 'what', 'why', 'help', 'question', 'advice'])
        or submission.link_flair_text in ['Question', 'Help', 'Discussion']
    )
```

- [ ] Search subreddit for keyword
- [ ] Filter for questions/help posts
- [ ] Include weekly threads
- [ ] Limit to recent posts (last 7 days)

---

### 2.7 Node: RankThreads

**Purpose**: Score and select best thread to reply to

**Implementation**:
```python
async def rank_threads(state: Dict[str, Any]) -> Dict[str, Any]:
    """Rank threads and pick the best one."""
    threads = state['threads']
    
    if not threads:
        return {"error": "No suitable threads found"}
    
    # Score each thread
    for thread in threads:
        score = 0.0
        
        # Recency (prefer last 2-3 days)
        age_days = (time.time() - thread['created_utc']) / 86400
        if age_days < 3:
            score += 10
        elif age_days < 7:
            score += 5
        
        # Few comments (opportunity to be helpful)
        if thread['num_comments'] < 5:
            score += 8
        elif thread['num_comments'] < 15:
            score += 4
        
        # Positive score (active post)
        if thread['score'] > 5:
            score += 5
        
        # Question in title
        if '?' in thread['title']:
            score += 3
        
        thread['rank_score'] = score
    
    # Sort by score
    threads.sort(key=lambda t: t['rank_score'], reverse=True)
    
    # Pick top thread
    best_thread = threads[0]
    
    # Save to threads table
    await db.execute(
        """
        insert into threads (
            company_id, subreddit, reddit_id, title, body, url, 
            rank_score, discovered_at
        ) values (%s, %s, %s, %s, %s, %s, %s, now())
        on conflict (company_id, reddit_id) do nothing
        """,
        state['company_id'],
        state['subreddit_candidate']['name'],
        best_thread['reddit_id'],
        best_thread['title'],
        best_thread['body'],
        best_thread['url'],
        best_thread['rank_score']
    )
    
    return {"thread": best_thread}
```

- [ ] Implement scoring heuristics
- [ ] Sort threads
- [ ] Pick best candidate
- [ ] Save to database

---

### 2.8 Node: RAGRetrieveCompanyData

**Purpose**: Find relevant company knowledge using vector similarity

**Implementation** (`graph/nodes/rag_retrieve.py`):
```python
from langchain_openai import OpenAIEmbeddings

async def rag_retrieve(state: Dict[str, Any]) -> Dict[str, Any]:
    """Retrieve relevant company docs using RAG."""
    company_id = state['company_id']
    thread = state['thread']
    keyword = state['keyword']
    
    # Build query from thread context
    query_text = f"""
    Keyword: {keyword}
    Question: {thread['title']}
    Details: {thread['body'][:500]}
    """
    
    # Get embedding
    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
    query_vector = await embeddings.aembed_query(query_text)
    
    # Similarity search in pgvector
    results = await db.fetch(
        """
        select 
            cdc.id,
            cdc.chunk_text,
            cd.title as doc_title,
            cd.source,
            1 - (cdc.embedding <=> %s::vector) as similarity
        from company_doc_chunks cdc
        join company_docs cd on cd.id = cdc.doc_id
        where cdc.company_id = %s
        order by cdc.embedding <=> %s::vector
        limit 5
        """,
        query_vector,
        company_id,
        query_vector
    )
    
    # Format context
    rag_context = {
        "chunk_ids": [r['id'] for r in results],
        "snippets": [
            {
                "text": r['chunk_text'],
                "doc_title": r['doc_title'],
                "source": r['source'],
                "similarity": float(r['similarity'])
            }
            for r in results
        ]
    }
    
    return {"rag_context": rag_context}
```

- [ ] Generate query embedding
- [ ] Run vector similarity search
- [ ] Return top-k chunks
- [ ] Format for prompt context

---

### 2.9 Node: DraftCompose

**Purpose**: Generate initial draft using LLM with all context

**Implementation**:
```python
async def draft_compose(state: Dict[str, Any]) -> Dict[str, Any]:
    """Compose draft reply using company prompt + RAG context."""
    
    # Get company prompt
    prompt_row = await db.fetchone(
        "select body, model, temperature from prompts where id = %s",
        state['prompt_id']
    )
    
    # Build context
    thread = state['thread']
    rag_snippets = state['rag_context']['snippets']
    rules = state['subreddit_rules']
    
    # Construct prompt
    system_prompt = f"""You are drafting a helpful reply for r/{state['subreddit_candidate']['name']}.

Company Instructions:
{prompt_row['body']}

Subreddit Rules:
- No links: {rules.get('no_links', True)}
- Tone: {rules.get('tone_requirements', 'helpful and informative')}
- Restrictions: {rules.get('other_restrictions', 'None')}

Company Knowledge (use if relevant):
{format_rag_snippets(rag_snippets)}

Thread Question:
Title: {thread['title']}
Body: {thread['body']}

Write a helpful, natural reply. Do NOT include any links. Keep it conversational."""
    
    llm = ChatOpenAI(
        model=prompt_row['model'],
        temperature=prompt_row['temperature']
    )
    
    result = await llm.ainvoke(system_prompt)
    draft_text = result.content.strip()
    
    return {
        "draft": {
            "text": draft_text,
            "variants": [],
            "risk": "unknown"
        }
    }

def format_rag_snippets(snippets):
    if not snippets:
        return "No specific company knowledge available."
    
    lines = []
    for i, snip in enumerate(snippets, 1):
        lines.append(f"{i}. [{snip['doc_title']}] {snip['text'][:200]}...")
    return "\n".join(lines)
```

- [ ] Fetch company prompt
- [ ] Build comprehensive prompt with context
- [ ] Call LLM
- [ ] Return draft text

---

### 2.10 Node: VaryDraft

**Purpose**: Generate 2-3 paraphrased variants for human choice

**Implementation**:
```python
async def vary_draft(state: Dict[str, Any]) -> Dict[str, Any]:
    """Generate paraphrased variants."""
    original_draft = state['draft']['text']
    
    llm = ChatOpenAI(model="gpt-5-mini", temperature=0.7)
    
    variants = []
    for i in range(2):
        prompt = f"""Paraphrase this comment while keeping the same meaning and helpfulness.

Original:
{original_draft}

Create a natural variant with:
- Different phrasing
- Similar length
- Same key points
- Conversational tone

Variant:"""
        
        result = await llm.ainvoke(prompt)
        variant_text = result.content.strip()
        
        # Deduplicate (check similarity)
        if not is_too_similar(variant_text, original_draft, variants):
            variants.append(variant_text)
    
    state['draft']['variants'] = variants
    return state

def is_too_similar(text, original, existing_variants, threshold=0.9):
    """Check if variant is too similar to original or other variants."""
    # Use simple Levenshtein or embedding similarity
    # Return True if similarity > threshold
    return False  # Placeholder
```

- [ ] Generate 2-3 variants
- [ ] Use higher temperature for variety
- [ ] Deduplicate similar variants
- [ ] Check against recent post history

---

### 2.11 Node: JudgeDraft (LLM Quality Gate)

**Purpose**: Evaluate draft quality; regenerate or reject if poor

**Implementation**:
```python
async def judge_draft(state: Dict[str, Any]) -> Dict[str, Any]:
    """Judge draft quality. Regenerate if needed."""
    draft_text = state['draft']['text']
    rules = state['subreddit_rules']
    thread = state['thread']
    
    judge_prompt = f"""Evaluate this draft comment for quality and rule compliance.

Subreddit Rules:
{rules}

Thread:
{thread['title']}

Draft:
{draft_text}

Check for:
1. Links (forbidden)
2. Self-promotion or spam
3. Off-topic or unhelpful
4. Rule violations
5. Overall quality

Respond in JSON:
{{
  "acceptable": true/false,
  "risk": "low" | "medium" | "high",
  "violations": ["list of issues"],
  "suggestions": "how to improve"
}}
"""
    
    llm = ChatOpenAI(model="gpt-5-mini", temperature=0.2)
    result = await llm.ainvoke(judge_prompt)
    judgment = parse_json(result.content)
    
    # Save judgment
    state['judgments']['draft'] = judgment
    state['draft']['risk'] = judgment['risk']
    
    # If not acceptable, try to regenerate (up to 2 times)
    if not judgment['acceptable']:
        retry_count = state.get('retry_count', 0)
        
        if retry_count < 2:
            # Regenerate with constraints
            # Call draft_compose again with suggestions
            # Increment retry_count
            pass  # Implement regeneration logic
        else:
            # Record as rejected, don't surface
            await db.execute(
                """
                insert into training_events (
                    company_id, event_type, human_reason, llm_judge
                ) values (%s, 'rejected_draft', %s, %s)
                """,
                state['company_id'],
                judgment['suggestions'],
                json.dumps(judgment)
            )
            return {"error": "Draft quality too low after retries"}
    
    return state
```

- [ ] Implement draft evaluation prompt
- [ ] Check for violations
- [ ] Regenerate if unacceptable (with retry limit)
- [ ] Log rejected drafts for training

---

### 2.12 Node: EmitReadyForReview

**Purpose**: Save artifact to database for human review

**Implementation**:
```python
async def emit_ready(state: Dict[str, Any]) -> Dict[str, Any]:
    """Save ready_artifacts and draft_versions."""
    
    # Insert artifact
    artifact_id = await db.fetchval(
        """
        insert into ready_artifacts (
            company_id, reddit_account_id, subreddit, keyword, company_goal,
            thread_reddit_id, rules_summary, draft_primary, draft_variants,
            rag_context, judge_subreddit, judge_draft, prompt_id, status
        ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'new')
        returning id
        """,
        state['company_id'],
        state['reddit_account_id'],
        state['subreddit_candidate']['name'],
        state['keyword'],
        state['company_goal'],
        state['thread']['reddit_id'],
        json.dumps(state['subreddit_rules']),
        state['draft']['text'],
        state['draft']['variants'],
        json.dumps(state['rag_context']),
        json.dumps(state['judgments']['subreddit']),
        json.dumps(state['judgments']['draft']),
        state['prompt_id']
    )
    
    # Insert initial draft version
    await db.execute(
        """
        insert into draft_versions (
            artifact_id, kind, text, created_by
        ) values (%s, 'generated', %s, %s)
        """,
        artifact_id,
        state['draft']['text'],
        state['user_id']
    )
    
    # Insert variants
    for variant in state['draft']['variants']:
        await db.execute(
            """
            insert into draft_versions (
                artifact_id, kind, text, created_by
            ) values (%s, 'generated', %s, %s)
            """,
            artifact_id,
            variant,
            state['user_id']
        )
    
    # Record training event
    await db.execute(
        """
        insert into training_events (
            company_id, artifact_id, event_type, llm_judge
        ) values (%s, %s, 'generated_draft', %s)
        """,
        state['company_id'],
        artifact_id,
        json.dumps(state['judgments']['draft'])
    )
    
    return {"artifact_id": artifact_id}
```

- [ ] Insert into `ready_artifacts`
- [ ] Insert into `draft_versions`
- [ ] Record training event
- [ ] Return artifact ID

---

### 2.13 Build Graph with Database Persistence

**CRITICAL: LangGraph MUST use database-backed checkpointer, NOT in-memory storage.**

Cloud Run is stateless - instances can be killed/restarted at any time. Using in-memory storage will lose all state.

**Implementation** (`graph/build.py`):
```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.postgres import PostgresSaver
from graph.state import GenerateState
from graph.nodes import *
from core.config import settings
import asyncpg

async def get_checkpointer():
    """Create PostgreSQL checkpointer for persistent state."""
    pool = await asyncpg.create_pool(settings.db_conn)
    
    # PostgresSaver expects synchronous connection, so we use connection string
    return PostgresSaver.from_conn_string(settings.db_conn)

def build_generate_graph(checkpointer=None):
    """
    Build LangGraph with database persistence.
    
    Args:
        checkpointer: PostgresSaver instance. If None, creates one.
    """
    graph = StateGraph(GenerateState)
    
    # Add nodes
    graph.add_node("fetch_subreddits", fetch_subreddits)
    graph.add_node("apply_history_filter", apply_history_filter)
    graph.add_node("judge_subreddit", judge_subreddit)
    graph.add_node("fetch_rules", fetch_rules)
    graph.add_node("fetch_threads", fetch_threads)
    graph.add_node("rank_threads", rank_threads)
    graph.add_node("rag_retrieve", rag_retrieve)
    graph.add_node("draft_compose", draft_compose)
    graph.add_node("vary_draft", vary_draft)
    graph.add_node("judge_draft", judge_draft)
    graph.add_node("emit_ready", emit_ready)
    
    # Define flow
    graph.set_entry_point("fetch_subreddits")
    graph.add_edge("fetch_subreddits", "apply_history_filter")
    graph.add_edge("apply_history_filter", "judge_subreddit")
    
    # Conditional: if judge_subreddit fails, end
    graph.add_conditional_edges(
        "judge_subreddit",
        lambda state: "continue" if not state.get('error') else "end",
        {
            "continue": "fetch_rules",
            "end": END
        }
    )
    
    graph.add_edge("fetch_rules", "fetch_threads")
    graph.add_edge("fetch_threads", "rank_threads")
    graph.add_edge("rank_threads", "rag_retrieve")
    graph.add_edge("rag_retrieve", "draft_compose")
    graph.add_edge("draft_compose", "vary_draft")
    graph.add_edge("vary_draft", "judge_draft")
    
    # Conditional: if judge_draft fails, end
    graph.add_conditional_edges(
        "judge_draft",
        lambda state: "emit" if not state.get('error') else "end",
        {
            "emit": "emit_ready",
            "end": END
        }
    )
    
    graph.add_edge("emit_ready", END)
    
    # CRITICAL: Compile with database checkpointer
    # This ensures state persists across Cloud Run instance restarts
    if checkpointer is None:
        checkpointer = PostgresSaver.from_conn_string(settings.db_conn)
    
    return graph.compile(checkpointer=checkpointer)
```

**Checkpointer Singleton** (`graph/checkpointer.py`):
```python
from langgraph.checkpoint.postgres import PostgresSaver
from core.config import settings
from functools import lru_cache

@lru_cache(maxsize=1)
def get_graph_checkpointer():
    """
    Get singleton PostgresSaver instance.
    
    This is cached to reuse the same connection pool across requests.
    """
    return PostgresSaver.from_conn_string(settings.db_conn)
```

- [ ] Build graph with all nodes
- [ ] Add conditional edges for gates
- [ ] **Configure PostgresSaver for database persistence**
- [ ] Test flow end-to-end with checkpoint resume

---

### 2.14 API Endpoint with Thread ID

**Endpoint**: `POST /api/generate`

```python
# api/generate.py
from fastapi import APIRouter, Depends, BackgroundTasks
from graph.build import build_generate_graph
from graph.checkpointer import get_graph_checkpointer
import uuid

router = APIRouter()

@router.post("/generate")
async def generate_artifacts(
    request: GenerateRequest,
    background_tasks: BackgroundTasks,
    user = Depends(get_current_user)
):
    """Trigger generation flow for a keyword."""
    
    # Generate unique thread_id for this run
    # Format: {company_id}:{keyword}:{timestamp}
    thread_id = f"{user.company_id}:{request.keywords[0]}:{uuid.uuid4().hex[:8]}"
    
    # Build initial state
    initial_state = {
        "company_id": user.company_id,
        "user_id": user.id,
        "company_goal": request.company_goal,
        "keywords": request.keywords,
        "keyword": request.keywords[0],  # Process first keyword
        "reddit_account_id": request.reddit_account_id,
        "prompt_id": request.prompt_id,
        "retry_count": 0
    }
    
    # Get checkpointer (singleton)
    checkpointer = get_graph_checkpointer()
    
    # Build graph with database persistence
    graph = build_generate_graph(checkpointer=checkpointer)
    
    # Configure with thread_id for checkpoint tracking
    config = {
        "configurable": {
            "thread_id": thread_id,
            "checkpoint_ns": f"company:{user.company_id}"
        }
    }
    
    # Run graph asynchronously
    # State is persisted in langgraph_checkpoints table at each node
    result = await graph.ainvoke(initial_state, config=config)
    
    if result.get('error'):
        return {
            "success": False,
            "error": result['error'],
            "thread_id": thread_id  # Allow resume if needed
        }
    
    return {
        "success": True,
        "artifact_id": result.get('artifact_id'),
        "thread_id": thread_id
    }

@router.get("/generate/status/{thread_id}")
async def get_generation_status(
    thread_id: str,
    user = Depends(get_current_user)
):
    """Check status of a generation run by thread_id."""
    
    # Get checkpointer
    checkpointer = get_graph_checkpointer()
    
    # Get latest checkpoint for this thread
    checkpoint = checkpointer.get(
        {
            "configurable": {
                "thread_id": thread_id,
                "checkpoint_ns": f"company:{user.company_id}"
            }
        }
    )
    
    if not checkpoint:
        return {"status": "not_found"}
    
    # Extract state from checkpoint
    state = checkpoint.get("channel_values", {})
    
    return {
        "status": "completed" if state.get('artifact_id') else "in_progress",
        "thread_id": thread_id,
        "error": state.get('error'),
        "artifact_id": state.get('artifact_id'),
        "current_node": checkpoint.get("pending_writes", [])
    }

@router.post("/generate/resume/{thread_id}")
async def resume_generation(
    thread_id: str,
    user = Depends(get_current_user)
):
    """Resume a failed or interrupted generation run."""
    
    checkpointer = get_graph_checkpointer()
    graph = build_generate_graph(checkpointer=checkpointer)
    
    config = {
        "configurable": {
            "thread_id": thread_id,
            "checkpoint_ns": f"company:{user.company_id}"
        }
    }
    
    # Get checkpoint to verify it exists
    checkpoint = checkpointer.get(config)
    if not checkpoint:
        raise HTTPException(status_code=404, detail="Thread not found")
    
    # Resume from last checkpoint
    # LangGraph will continue from where it left off
    result = await graph.ainvoke(None, config=config)
    
    return {
        "success": True,
        "artifact_id": result.get('artifact_id'),
        "thread_id": thread_id
    }
```

**Why Thread IDs are Critical:**
- Cloud Run instances are stateless and ephemeral
- If instance crashes mid-execution, state is preserved in database
- Can resume from exact point of failure using thread_id
- Enables debugging by inspecting checkpoint history
- Allows concurrent runs without state collision

- [ ] Create API endpoint with thread_id
- [ ] Accept keywords, goal, prompt_id
- [ ] Run graph with PostgresSaver config
- [ ] Return artifact ID and thread_id
- [ ] Implement status and resume endpoints

---

## Testing

### Unit Tests
- [ ] Test each node independently
- [ ] Mock LLM responses
- [ ] Mock Reddit API
- [ ] Mock database

### Integration Tests
- [ ] Test full graph execution
- [ ] Verify artifact created
- [ ] Check subreddit_history updates
- [ ] Verify training_events logged

### Manual Tests
- [ ] Run with real keyword
- [ ] Check artifact in database
- [ ] Verify RAG context included
- [ ] Review draft quality

---

## Success Metrics

- [ ] Graph executes end-to-end without errors
- [ ] Bad subreddits filtered correctly
- [ ] RAG retrieves relevant context
- [ ] Drafts are coherent and helpful
- [ ] Artifacts appear in database
- [ ] No crashes or hung processes

---

## Next Steps
Proceed to **M3-REVIEW-UI.md** to build the review and approval interface.

