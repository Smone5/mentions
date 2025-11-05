# LangGraph Generation Flow

**Purpose**: Complete implementation guide for the LangGraph-based draft generation pipeline.

**Related**: [M2-GENERATION-FLOW.md](./M2-GENERATION-FLOW.md), [31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md)

---

## Overview

The generation flow uses LangGraph to orchestrate a multi-step pipeline that:
1. Finds relevant subreddits for keywords
2. Gates subreddits with LLM judge (hard stop)
3. Fetches hot threads from approved subreddits
4. Ranks threads by relevance
5. Retrieves company knowledge via RAG
6. Drafts replies grounded in company data
7. Creates variations
8. Judges draft quality (hard stop)
9. Saves approved drafts for human review

**All state persists in PostgreSQL** (not local memory) for Cloud Run compatibility.

---

## State Definition

```python
# graph/state.py
from typing import TypedDict, List, Optional

class GenerateState(TypedDict):
    # Input
    company_id: str
    user_id: str
    company_goal: str
    keyword: str
    keywords: List[str]
    reddit_account_id: str
    prompt_id: str
    
    # Subreddit discovery
    subreddits: List[dict]  # [{"name": "...", "subscribers": ...}]
    subreddit: str  # Current subreddit being processed
    subreddit_approved: bool
    subreddit_rules: str
    
    # Thread discovery
    threads: List[dict]  # [{"id": "...", "title": "...", "score": ...}]
    thread: dict  # Selected thread
    top_comments: List[dict]
    
    # RAG
    rag_chunks: List[str]
    
    # Draft generation
    draft: str
    variations: List[str]
    draft_approved: bool
    
    # Output
    artifact_id: str
    draft_id: str
    
    # Error handling
    error: Optional[str]
    retry_count: int
```

---

## Checkpointer Setup

```python
# graph/checkpointer.py
from langgraph.checkpoint.postgres import PostgresSaver
from core.config import settings

_checkpointer = None

def get_graph_checkpointer() -> PostgresSaver:
    """
    Get singleton PostgreSQL checkpointer for LangGraph.
    
    CRITICAL: Uses database for state persistence, not local memory.
    Required for Cloud Run (stateless containers).
    """
    global _checkpointer
    
    if _checkpointer is None:
        _checkpointer = PostgresSaver.from_conn_string(settings.DB_CONN)
    
    return _checkpointer
```

---

## Node Implementations

### Node 1: Fetch Subreddits

```python
# graph/nodes/fetch_subreddits.py
async def fetch_subreddits(state: GenerateState) -> GenerateState:
    """
    Search Reddit for relevant subreddits based on keyword.
    """
    keyword = state["keyword"]
    reddit_account_id = state["reddit_account_id"]
    company_id = state["company_id"]
    
    logger.info(f"Searching subreddits for keyword: {keyword}")
    
    try:
        # Get Reddit client
        reddit_client = await get_reddit_client(company_id, reddit_account_id)
        
        # Search subreddits
        subreddits = await reddit_client.search_subreddits(keyword, limit=20)
        
        # Filter out quarantined/NSFW
        filtered = [
            s for s in subreddits
            if not s.get("quarantine") and not s.get("over18")
        ]
        
        state["subreddits"] = filtered
        logger.info(f"Found {len(filtered)} subreddits")
        
        return state
        
    except Exception as e:
        logger.error(f"Failed to fetch subreddits: {e}")
        state["error"] = f"Subreddit search failed: {e}"
        return state
```

### Node 2: Judge Subreddit (HARD GATE)

```python
# graph/nodes/judge_subreddit.py
async def judge_subreddit(state: GenerateState) -> GenerateState:
    """
    LLM judge determines if subreddit is appropriate.
    
    CRITICAL: This is a HARD GATE (Rule 3). Rejection stops the pipeline.
    """
    subreddit = state["subreddit"]
    keyword = state["keyword"]
    company_goal = state["company_goal"]
    
    logger.info(f"Judging subreddit: r/{subreddit}")
    
    # Fetch subreddit info
    reddit_client = await get_reddit_client(state["company_id"], state["reddit_account_id"])
    subreddit_info = await reddit_client.get_subreddit_info(subreddit)
    
    # LLM judge prompt
    prompt = f"""You are evaluating if a subreddit is appropriate for authentic participation.

Company Goal: {company_goal}
Keyword: {keyword}
Subreddit: r/{subreddit}
Description: {subreddit_info.get('description', 'N/A')}
Subscribers: {subreddit_info.get('subscribers', 0)}
Rules: {subreddit_info.get('rules', 'N/A')[:500]}

Is this subreddit appropriate for authentic, helpful participation related to "{keyword}"?

Consider:
1. Is the topic relevant to the keyword?
2. Is the community active and legitimate?
3. Would participation seem natural, not promotional?
4. Does it allow the types of discussions we want?

CRITICAL RULES:
- Reject if subreddit bans promotional content
- Reject if subreddit is too small (<1000 subscribers)
- Reject if topic is completely unrelated

Answer format:
VERDICT: [APPROVE or REJECT]
REASON: [One sentence explanation]
CONFIDENCE: [0.0 to 1.0]"""
    
    # Call LLM with low temperature for consistency
    response = await llm_client.generate(prompt, temperature=0.2)
    
    # Parse response
    verdict = "REJECT"  # Default to reject
    if "VERDICT: APPROVE" in response:
        verdict = "APPROVE"
    
    # Extract reason
    reason_match = re.search(r'REASON: (.+)', response)
    reason = reason_match.group(1) if reason_match else "No reason provided"
    
    # HARD GATE: Reject stops pipeline
    if verdict == "REJECT":
        logger.warning(f"Subreddit r/{subreddit} REJECTED: {reason}")
        state["error"] = f"Subreddit rejected: {reason}"
        state["subreddit_approved"] = False
        return state
    
    logger.info(f"Subreddit r/{subreddit} APPROVED: {reason}")
    state["subreddit_approved"] = True
    
    return state
```

### Node 3-4: Fetch Rules & Threads

```python
# graph/nodes/fetch_rules.py
async def fetch_rules(state: GenerateState) -> GenerateState:
    """Fetch subreddit rules."""
    subreddit = state["subreddit"]
    
    reddit_client = await get_reddit_client(state["company_id"], state["reddit_account_id"])
    rules = await reddit_client.get_subreddit_rules(subreddit)
    
    state["subreddit_rules"] = "\n".join([f"{i+1}. {r['short_name']}: {r['description']}" for i, r in enumerate(rules)])
    
    return state

# graph/nodes/fetch_threads.py
async def fetch_threads(state: GenerateState) -> GenerateState:
    """Fetch hot threads from subreddit."""
    subreddit = state["subreddit"]
    keyword = state["keyword"]
    
    reddit_client = await get_reddit_client(state["company_id"], state["reddit_account_id"])
    
    # Get hot threads
    threads = await reddit_client.get_hot_threads(subreddit, limit=50)
    
    # Filter: must mention keyword (case-insensitive)
    keyword_lower = keyword.lower()
    relevant_threads = [
        t for t in threads
        if keyword_lower in t["title"].lower() or keyword_lower in t["selftext"].lower()
    ]
    
    state["threads"] = relevant_threads
    logger.info(f"Found {len(relevant_threads)} relevant threads in r/{subreddit}")
    
    return state
```

### Node 5: Rank Threads

```python
# graph/nodes/rank_threads.py
async def rank_threads(state: GenerateState) -> GenerateState:
    """
    Use LLM to rank threads by relevance and reply-worthiness.
    """
    threads = state["threads"]
    keyword = state["keyword"]
    company_goal = state["company_goal"]
    
    if not threads:
        state["error"] = "No relevant threads found"
        return state
    
    # Take top 10 for ranking
    top_threads = threads[:10]
    
    # Format threads for LLM
    thread_list = "\n\n".join([
        f"THREAD {i+1}:\nTitle: {t['title']}\nBody: {t['selftext'][:200]}...\nScore: {t['score']}, Comments: {t['num_comments']}"
        for i, t in enumerate(top_threads)
    ])
    
    prompt = f"""Rank these Reddit threads by how appropriate they are for a helpful, authentic reply.

Keyword: {keyword}
Company Goal: {company_goal}

{thread_list}

Rank threads from best to worst opportunity. Consider:
1. Does the question/discussion relate to our keyword?
2. Is there room for a helpful contribution?
3. Is the thread active (recent, has engagement)?
4. Would our reply add value?

Output format:
BEST: [Thread number]
REASON: [Why this is the best opportunity]"""
    
    response = await llm_client.generate(prompt, temperature=0.3)
    
    # Parse best thread
    best_match = re.search(r'BEST: (\d+)', response)
    if best_match:
        best_idx = int(best_match.group(1)) - 1
        state["thread"] = top_threads[best_idx]
    else:
        # Fallback: highest scoring thread
        state["thread"] = max(top_threads, key=lambda t: t['score'])
    
    logger.info(f"Selected thread: {state['thread']['title']}")
    
    return state
```

### Node 6: RAG Retrieve

```python
# graph/nodes/rag_retrieve.py
from rag.retrieve import semantic_search

async def rag_retrieve(state: GenerateState) -> GenerateState:
    """
    Retrieve relevant company knowledge for grounding the reply.
    """
    company_id = state["company_id"]
    thread = state["thread"]
    keyword = state["keyword"]
    
    # Build query from thread context
    query = f"{keyword} {thread['title']} {thread['selftext'][:200]}"
    
    # Retrieve top chunks
    chunks = await semantic_search(
        company_id=company_id,
        query=query,
        limit=5
    )
    
    state["rag_chunks"] = [c["chunk_text"] for c in chunks]
    logger.info(f"Retrieved {len(chunks)} RAG chunks")
    
    return state
```

### Node 7-8: Draft Compose & Vary

```python
# graph/nodes/draft_compose.py
async def draft_compose(state: GenerateState) -> GenerateState:
    """
    Compose draft reply grounded in company knowledge.
    """
    # Get prompt template
    prompt_template = await get_prompt_template(state["prompt_id"])
    
    # Render with context
    rendered_prompt = prompt_template.render(
        keyword=state["keyword"],
        subreddit=state["subreddit"],
        subreddit_rules=state["subreddit_rules"],
        thread_title=state["thread"]["title"],
        thread_body=state["thread"]["selftext"],
        top_comments=state.get("top_comments", []),
        company_data="\n\n".join(state["rag_chunks"]),
        company_goal=state["company_goal"]
    )
    
    # Generate draft (higher temperature for creativity)
    draft = await llm_client.generate(rendered_prompt, temperature=0.6)
    
    state["draft"] = draft
    logger.info(f"Generated draft ({len(draft)} chars)")
    
    return state

# graph/nodes/vary_draft.py
async def vary_draft(state: GenerateState) -> GenerateState:
    """Create 2-3 variations of the draft."""
    base_draft = state["draft"]
    
    variations = []
    for i in range(2):
        prompt = f"""Rewrite this Reddit reply to be slightly different while keeping the same meaning and helpfulness.

Original: {base_draft}

CRITICAL: Do NOT include any links or URLs.

Variation {i+1}:"""
        
        variation = await llm_client.generate(prompt, temperature=0.7)
        variations.append(variation)
    
    state["variations"] = variations
    
    return state
```

### Node 9: Judge Draft (HARD GATE)

```python
# graph/nodes/judge_draft.py
async def judge_draft(state: GenerateState) -> GenerateState:
    """
    LLM judge determines if draft is high quality and safe.
    
    CRITICAL: This is a HARD GATE (Rule 3). Rejection stops the pipeline.
    """
    draft = state["draft"]
    subreddit_rules = state["subreddit_rules"]
    
    # HARD CHECK: No links (Rule 2)
    is_valid, reason = validate_no_links(draft)
    if not is_valid:
        logger.error(f"Draft contains links: {reason}")
        state["error"] = f"Draft rejected: {reason}"
        state["draft_approved"] = False
        return state
    
    # LLM quality judge
    prompt = f"""Evaluate this Reddit reply draft for quality and safety.

Draft: {draft}

Subreddit Rules: {subreddit_rules}

Evaluate:
1. Is it helpful and informative?
2. Does it answer the question or contribute to discussion?
3. Is the tone appropriate (friendly, not salesy)?
4. Does it follow subreddit rules?
5. Does it avoid promotional language?
6. Is it free of links/URLs?

VERDICT: [APPROVE or REJECT]
REASON: [One sentence]
RISK_LEVEL: [LOW, MEDIUM, or HIGH]"""
    
    response = await llm_client.generate(prompt, temperature=0.2)
    
    # Parse verdict
    verdict = "REJECT"
    if "VERDICT: APPROVE" in response:
        verdict = "APPROVE"
    
    # Parse risk level
    risk_level = "MEDIUM"
    if "RISK_LEVEL: LOW" in response:
        risk_level = "LOW"
    elif "RISK_LEVEL: HIGH" in response:
        risk_level = "HIGH"
    
    # Extract reason
    reason_match = re.search(r'REASON: (.+)', response)
    reason = reason_match.group(1) if reason_match else "No reason"
    
    # HARD GATE
    if verdict == "REJECT":
        logger.warning(f"Draft REJECTED: {reason}")
        state["error"] = f"Draft quality check failed: {reason}"
        state["draft_approved"] = False
        return state
    
    logger.info(f"Draft APPROVED ({risk_level} risk): {reason}")
    state["draft_approved"] = True
    state["risk_level"] = risk_level.lower()
    
    return state
```

### Node 10: Emit Ready

```python
# graph/nodes/emit_ready.py
async def emit_ready(state: GenerateState) -> GenerateState:
    """
    Save approved draft to database for human review.
    """
    # Create artifact
    artifact_id = str(uuid.uuid4())
    thread_id = state["thread"]["id"]  # UUID from threads table
    
    await db.execute(
        """
        INSERT INTO artifacts (
            id, company_id, reddit_account_id, keyword, subreddit,
            thread_id, thread_reddit_id, thread_title, thread_body, thread_url, 
            prompt_id, status, draft_primary, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'new', $12, NOW())
        """,
        artifact_id,
        state["company_id"],
        state["reddit_account_id"],
        state["keyword"],
        state["subreddit"],
        thread_id,
        state["thread"]["reddit_id"],
        state["thread"]["title"],
        state["thread"]["selftext"],
        state["thread"]["url"],
        state["prompt_id"],
        state["draft"]  # draft_primary is NOT NULL
    )
    
    # Create primary draft
    draft_id = str(uuid.uuid4())
    await db.execute(
        """
        INSERT INTO drafts (
            id, artifact_id, kind, text, risk, created_at
        ) VALUES ($1, $2, 'generated', $3, $4, NOW())
        """,
        draft_id,
        artifact_id,
        state["draft"],
        state.get("risk_level", "medium")
    )
    
    # Create variation drafts
    for variation in state.get("variations", []):
        await db.execute(
            """
            INSERT INTO drafts (
                id, artifact_id, kind, text, risk, source_draft_id, created_at
            ) VALUES ($1, $2, 'generated', $3, $4, $5, NOW())
            """,
            str(uuid.uuid4()),
            artifact_id,
            variation,
            state.get("risk_level", "medium"),
            draft_id  # Link variations to primary draft
        )
    
    state["artifact_id"] = artifact_id
    state["draft_id"] = draft_id
    
    logger.info(f"Saved draft {draft_id} for human review")
    
    return state
```

---

## Graph Builder

```python
# graph/build.py
from langgraph.graph import StateGraph, END
from graph.state import GenerateState
from graph.checkpointer import get_graph_checkpointer
from graph.nodes import *

def build_generate_graph():
    """
    Build LangGraph generation pipeline with database persistence.
    """
    graph = StateGraph(GenerateState)
    
    # Add all nodes
    graph.add_node("fetch_subreddits", fetch_subreddits)
    graph.add_node("judge_subreddit", judge_subreddit)
    graph.add_node("fetch_rules", fetch_rules)
    graph.add_node("fetch_threads", fetch_threads)
    graph.add_node("rank_threads", rank_threads)
    graph.add_node("rag_retrieve", rag_retrieve)
    graph.add_node("draft_compose", draft_compose)
    graph.add_node("vary_draft", vary_draft)
    graph.add_node("judge_draft", judge_draft)
    graph.add_node("emit_ready", emit_ready)
    
    # Set entry point
    graph.set_entry_point("fetch_subreddits")
    
    # Linear flow with conditional gates
    graph.add_edge("fetch_subreddits", "judge_subreddit")
    
    # Gate 1: Subreddit judge (hard stop on rejection)
    graph.add_conditional_edges(
        "judge_subreddit",
        lambda state: "end" if state.get("error") else "continue",
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
    
    # Gate 2: Draft judge (hard stop on rejection)
    graph.add_conditional_edges(
        "judge_draft",
        lambda state: "emit" if state.get("draft_approved") else "end",
        {
            "emit": "emit_ready",
            "end": END
        }
    )
    
    graph.add_edge("emit_ready", END)
    
    # CRITICAL: Compile with PostgreSQL checkpointer
    checkpointer = get_graph_checkpointer()
    return graph.compile(checkpointer=checkpointer)
```

---

## API Integration

```python
# api/generate.py
from fastapi import APIRouter, Depends
from graph.build import build_generate_graph
import uuid

router = APIRouter()

@router.post("/generate")
async def generate_artifacts(
    request: GenerateRequest,
    user = Depends(get_current_user)
):
    """
    Trigger draft generation pipeline.
    """
    # Generate unique thread_id for state tracking
    thread_id = f"{user.company_id}:{request.keyword}:{uuid.uuid4().hex[:8]}"
    
    # Build initial state
    initial_state = {
        "company_id": user.company_id,
        "user_id": user.id,
        "company_goal": request.company_goal,
        "keyword": request.keyword,
        "keywords": request.keywords,
        "reddit_account_id": request.reddit_account_id,
        "prompt_id": request.prompt_id,
        "retry_count": 0
    }
    
    # Build graph
    graph = build_generate_graph()
    
    # Configure with thread_id for checkpoint persistence
    config = {
        "configurable": {
            "thread_id": thread_id,
            "checkpoint_ns": f"company:{user.company_id}"
        }
    }
    
    # Run graph (state persists at each node)
    result = await graph.ainvoke(initial_state, config=config)
    
    if result.get("error"):
        return {
            "success": False,
            "error": result["error"],
            "thread_id": thread_id
        }
    
    return {
        "success": True,
        "artifact_id": result.get("artifact_id"),
        "draft_id": result.get("draft_id"),
        "thread_id": thread_id
    }
```

---

## Testing

```python
# tests/test_langgraph_flow.py
@pytest.mark.asyncio
async def test_full_generation_flow():
    """Test complete LangGraph pipeline."""
    initial_state = {
        "company_id": "test-company",
        "user_id": "test-user",
        "keyword": "project management",
        "company_goal": "Help teams collaborate better",
        "reddit_account_id": "test-account",
        "prompt_id": "test-prompt",
        "retry_count": 0
    }
    
    graph = build_generate_graph()
    config = {"configurable": {"thread_id": "test-thread"}}
    
    result = await graph.ainvoke(initial_state, config=config)
    
    # Should complete without error
    assert result.get("error") is None
    assert result.get("artifact_id") is not None
    assert result.get("draft") is not None
    
    # Draft should pass link check
    is_valid, _ = validate_no_links(result["draft"])
    assert is_valid == True
```

---

## Key Points

1. **Database Persistence**: All state stored in PostgreSQL, not memory
2. **Hard Gates**: Judge nodes enforce hard stops (Rule 3)
3. **No Links**: Draft always validated for links (Rule 2)
4. **Thread Safety**: unique `thread_id` per execution
5. **Error Handling**: Errors stop pipeline, state preserved
6. **Resume Capability**: Can resume from any checkpoint

**Reference**: [M2-GENERATION-FLOW.md](./M2-GENERATION-FLOW.md), [22-HARD-RULES.md](./22-HARD-RULES.md)

