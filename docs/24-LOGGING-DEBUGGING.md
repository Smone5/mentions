# Logging & Debugging Strategy

## Overview
Comprehensive logging is critical for debugging stateful workflows in a distributed, serverless environment where instances can be killed at any time.

**Key Requirements:**
- **Structured logging** for easy parsing and filtering
- **Request correlation** across services and nodes
- **State tracking** at each LangGraph node
- **Performance metrics** for optimization
- **Error context** for debugging failures

---

## Structured Logging Format

### Standard Log Format

All logs should follow this JSON structure:

```json
{
  "timestamp": "2025-11-05T10:23:45.123Z",
  "level": "INFO",
  "service": "mentions-backend",
  "environment": "prod",
  "request_id": "req_abc123",
  "thread_id": "company_uuid:keyword:abc123de",
  "company_id": "uuid",
  "user_id": "uuid",
  "node": "draft_compose",
  "action": "llm_call",
  "duration_ms": 1234,
  "message": "Draft composition completed",
  "metadata": {
    "model": "gpt-5-mini",
    "temperature": 0.6,
    "tokens": 450
  },
  "error": null
}
```

### Log Levels

- **DEBUG**: Detailed information for diagnosing problems
- **INFO**: Confirmation that things are working as expected
- **WARNING**: Indication something unexpected happened
- **ERROR**: A serious problem occurred
- **CRITICAL**: A very serious error that may cause the system to abort

---

## Logging Configuration

### Python Logger Setup

Create `core/logging_config.py`:

```python
import logging
import json
import sys
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from core.config import settings
from contextvars import ContextVar

# Context variables for request tracking
request_id_var: ContextVar[Optional[str]] = ContextVar('request_id', default=None)
thread_id_var: ContextVar[Optional[str]] = ContextVar('thread_id', default=None)
company_id_var: ContextVar[Optional[str]] = ContextVar('company_id', default=None)
user_id_var: ContextVar[Optional[str]] = ContextVar('user_id', default=None)
node_var: ContextVar[Optional[str]] = ContextVar('node', default=None)


class StructuredFormatter(logging.Formatter):
    """Format logs as JSON for GCP Cloud Logging."""
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": "mentions-backend",
            "environment": settings.env,
            "request_id": request_id_var.get(),
            "thread_id": thread_id_var.get(),
            "company_id": company_id_var.get(),
            "user_id": user_id_var.get(),
            "node": node_var.get(),
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data["error"] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "traceback": self.formatException(record.exc_info)
            }
        
        # Add extra fields
        if hasattr(record, 'metadata'):
            log_data["metadata"] = record.metadata
        
        if hasattr(record, 'duration_ms'):
            log_data["duration_ms"] = record.duration_ms
        
        if hasattr(record, 'action'):
            log_data["action"] = record.action
        
        # Remove None values
        log_data = {k: v for k, v in log_data.items() if v is not None}
        
        return json.dumps(log_data)


def setup_logging():
    """Configure structured logging for the application."""
    
    # Create handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(StructuredFormatter())
    
    # Configure root logger
    logger = logging.getLogger()
    logger.setLevel(getattr(logging, settings.log_level.upper(), logging.INFO))
    logger.handlers = [handler]
    
    # Suppress noisy loggers
    logging.getLogger('httpx').setLevel(logging.WARNING)
    logging.getLogger('httpcore').setLevel(logging.WARNING)
    logging.getLogger('asyncpraw').setLevel(logging.INFO)
    
    return logger


class RequestLogger:
    """Logger with request context."""
    
    def __init__(self, logger: logging.Logger):
        self.logger = logger
    
    def set_context(
        self,
        request_id: Optional[str] = None,
        thread_id: Optional[str] = None,
        company_id: Optional[str] = None,
        user_id: Optional[str] = None,
        node: Optional[str] = None
    ):
        """Set context variables for this request."""
        if request_id:
            request_id_var.set(request_id)
        if thread_id:
            thread_id_var.set(thread_id)
        if company_id:
            company_id_var.set(company_id)
        if user_id:
            user_id_var.set(user_id)
        if node:
            node_var.set(node)
    
    def info(self, message: str, action: str = None, metadata: Dict = None, duration_ms: int = None):
        """Log info with context."""
        extra = {}
        if action:
            extra['action'] = action
        if metadata:
            extra['metadata'] = metadata
        if duration_ms:
            extra['duration_ms'] = duration_ms
        self.logger.info(message, extra=extra)
    
    def error(self, message: str, action: str = None, metadata: Dict = None, exc_info=True):
        """Log error with context."""
        extra = {}
        if action:
            extra['action'] = action
        if metadata:
            extra['metadata'] = metadata
        self.logger.error(message, extra=extra, exc_info=exc_info)
    
    def warning(self, message: str, action: str = None, metadata: Dict = None):
        """Log warning with context."""
        extra = {}
        if action:
            extra['action'] = action
        if metadata:
            extra['metadata'] = metadata
        self.logger.warning(message, extra=extra)
    
    def debug(self, message: str, action: str = None, metadata: Dict = None):
        """Log debug with context."""
        extra = {}
        if action:
            extra['action'] = action
        if metadata:
            extra['metadata'] = metadata
        self.logger.debug(message, extra=extra)


# Initialize logger
logger = RequestLogger(setup_logging())
```

### FastAPI Integration

Update `main.py`:

```python
from fastapi import FastAPI, Request
from core.logging_config import logger, request_id_var
import uuid
import time

app = FastAPI(title="Mentions Backend")

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Add request ID and logging to all requests."""
    
    # Generate or extract request ID
    request_id = request.headers.get("X-Request-ID") or f"req_{uuid.uuid4().hex[:12]}"
    request_id_var.set(request_id)
    
    # Log request start
    start_time = time.time()
    logger.info(
        f"{request.method} {request.url.path}",
        action="request_start",
        metadata={
            "method": request.method,
            "path": request.url.path,
            "query": str(request.url.query)
        }
    )
    
    # Process request
    try:
        response = await call_next(request)
        
        # Log request completion
        duration_ms = int((time.time() - start_time) * 1000)
        logger.info(
            f"Request completed: {response.status_code}",
            action="request_complete",
            duration_ms=duration_ms,
            metadata={
                "status_code": response.status_code,
                "path": request.url.path
            }
        )
        
        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id
        return response
        
    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error(
            f"Request failed: {str(e)}",
            action="request_failed",
            metadata={
                "path": request.url.path,
                "error_type": type(e).__name__
            }
        )
        raise
```

---

## LangGraph Node Logging

### Node Execution Wrapper

Create `graph/logging.py`:

```python
from functools import wraps
import time
from typing import Dict, Any, Callable
from core.logging_config import logger, node_var

def log_node(node_name: str):
    """Decorator to add logging to LangGraph nodes."""
    
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(state: Dict[str, Any]) -> Dict[str, Any]:
            # Set node context
            node_var.set(node_name)
            
            # Log node start
            logger.info(
                f"Node '{node_name}' starting",
                action="node_start",
                metadata={
                    "node": node_name,
                    "company_id": state.get("company_id"),
                    "keyword": state.get("keyword"),
                    "thread_id": state.get("thread_id")
                }
            )
            
            start_time = time.time()
            
            try:
                # Execute node
                result = await func(state)
                
                # Log node completion
                duration_ms = int((time.time() - start_time) * 1000)
                logger.info(
                    f"Node '{node_name}' completed",
                    action="node_complete",
                    duration_ms=duration_ms,
                    metadata={
                        "node": node_name,
                        "has_error": bool(result.get("error")),
                        "state_keys": list(result.keys())
                    }
                )
                
                return result
                
            except Exception as e:
                # Log node failure
                duration_ms = int((time.time() - start_time) * 1000)
                logger.error(
                    f"Node '{node_name}' failed: {str(e)}",
                    action="node_failed",
                    metadata={
                        "node": node_name,
                        "error_type": type(e).__name__,
                        "duration_ms": duration_ms
                    }
                )
                
                # Return error state
                return {**state, "error": str(e)}
        
        return wrapper
    return decorator
```

### Example Node with Logging

Update node implementations:

```python
from graph.logging import log_node

@log_node("fetch_subreddits")
async def fetch_subreddits(state: Dict[str, Any]) -> Dict[str, Any]:
    """Search Reddit for candidate subreddits matching keyword."""
    
    keyword = state['keyword']
    
    logger.info(
        f"Searching subreddits for keyword: {keyword}",
        action="reddit_search",
        metadata={"keyword": keyword}
    )
    
    try:
        async with asyncpraw.Reddit(...) as reddit:
            subreddits = []
            async for subreddit in reddit.subreddits.search(keyword, limit=20):
                subreddits.append({
                    "name": subreddit.display_name,
                    "subscribers": subreddit.subscribers,
                    "active_users": getattr(subreddit, 'active_user_count', 0)
                })
            
            logger.info(
                f"Found {len(subreddits)} candidate subreddits",
                action="subreddits_found",
                metadata={
                    "count": len(subreddits),
                    "subreddits": [s["name"] for s in subreddits[:5]]  # Log first 5
                }
            )
            
            return {"subreddit_candidates": subreddits}
            
    except Exception as e:
        logger.error(
            f"Failed to fetch subreddits: {str(e)}",
            action="reddit_search_failed",
            metadata={"keyword": keyword}
        )
        raise

@log_node("judge_subreddit")
async def judge_subreddit(state: Dict[str, Any]) -> Dict[str, Any]:
    """LLM judges if subreddit is good fit. HARD GATE."""
    
    for candidate in state['subreddit_candidates']:
        subreddit = candidate['name']
        
        logger.info(
            f"Judging subreddit: r/{subreddit}",
            action="llm_judge_start",
            metadata={"subreddit": subreddit}
        )
        
        # Build prompt
        prompt = ChatPromptTemplate.from_messages([...])
        llm = ChatOpenAI(model="gpt-5-mini", temperature=0.2)
        
        start_time = time.time()
        result = await llm.ainvoke(prompt.format_messages(...))
        duration_ms = int((time.time() - start_time) * 1000)
        
        judgment = parse_json(result.content)
        
        logger.info(
            f"Subreddit r/{subreddit} judged: {judgment['ok']}",
            action="llm_judge_complete",
            duration_ms=duration_ms,
            metadata={
                "subreddit": subreddit,
                "ok": judgment['ok'],
                "score": judgment['score'],
                "reasoning": judgment['reasoning'][:100]  # Truncate for logs
            }
        )
        
        # Save to database
        await db.execute(...)
        
        if judgment['ok']:
            logger.info(
                f"Selected subreddit: r/{subreddit}",
                action="subreddit_selected",
                metadata={"subreddit": subreddit, "score": judgment['score']}
            )
            return {
                "subreddit_candidate": candidate,
                "judgments": {
                    "subreddit": judgment
                }
            }
        else:
            logger.debug(
                f"Rejected subreddit: r/{subreddit}",
                action="subreddit_rejected",
                metadata={"subreddit": subreddit, "reason": judgment['reasoning']}
            )
    
    logger.warning(
        "No suitable subreddit found after judging all candidates",
        action="no_subreddit_found",
        metadata={"candidates_count": len(state['subreddit_candidates'])}
    )
    
    return {"error": "No suitable subreddit found"}

@log_node("draft_compose")
async def draft_compose(state: Dict[str, Any]) -> Dict[str, Any]:
    """Compose draft reply using company prompt + RAG context."""
    
    thread = state['thread']
    subreddit = state['subreddit_candidate']['name']
    
    logger.info(
        f"Composing draft for r/{subreddit}",
        action="draft_start",
        metadata={
            "subreddit": subreddit,
            "thread_id": thread['reddit_id'],
            "thread_title": thread['title'][:50]
        }
    )
    
    # Get company prompt
    prompt_row = await db.fetchone(
        "select body, model, temperature from prompts where id = %s",
        state['prompt_id']
    )
    
    # Build context
    rag_snippets = state['rag_context']['snippets']
    
    logger.debug(
        f"Using {len(rag_snippets)} RAG snippets",
        action="rag_context",
        metadata={"snippet_count": len(rag_snippets)}
    )
    
    # Call LLM
    llm = ChatOpenAI(
        model=prompt_row['model'],
        temperature=prompt_row['temperature']
    )
    
    start_time = time.time()
    result = await llm.ainvoke(system_prompt)
    duration_ms = int((time.time() - start_time) * 1000)
    
    draft_text = result.content.strip()
    
    logger.info(
        f"Draft composed: {len(draft_text)} characters",
        action="draft_complete",
        duration_ms=duration_ms,
        metadata={
            "model": prompt_row['model'],
            "temperature": prompt_row['temperature'],
            "draft_length": len(draft_text),
            "draft_preview": draft_text[:100]
        }
    )
    
    return {
        "draft": {
            "text": draft_text,
            "variants": [],
            "risk": "unknown"
        }
    }
```

---

## API Endpoint Logging

### Generate Endpoint with Full Logging

```python
from core.logging_config import logger
import uuid

@router.post("/generate")
async def generate_artifacts(
    request: GenerateRequest,
    user = Depends(get_current_user)
):
    """Trigger generation flow for a keyword."""
    
    # Set context
    logger.set_context(
        company_id=user.company_id,
        user_id=user.id
    )
    
    # Generate thread_id
    thread_id = f"{user.company_id}:{request.keywords[0]}:{uuid.uuid4().hex[:8]}"
    logger.set_context(thread_id=thread_id)
    
    logger.info(
        f"Starting generation for keyword: {request.keywords[0]}",
        action="generation_start",
        metadata={
            "keyword": request.keywords[0],
            "thread_id": thread_id,
            "company_goal": request.company_goal[:100]
        }
    )
    
    try:
        # Build initial state
        initial_state = {
            "company_id": user.company_id,
            "user_id": user.id,
            "company_goal": request.company_goal,
            "keywords": request.keywords,
            "keyword": request.keywords[0],
            "reddit_account_id": request.reddit_account_id,
            "prompt_id": request.prompt_id,
            "retry_count": 0,
            "thread_id": thread_id  # Include for node logging
        }
        
        # Get checkpointer
        checkpointer = get_graph_checkpointer()
        graph = build_generate_graph(checkpointer=checkpointer)
        
        # Configure with thread_id
        config = {
            "configurable": {
                "thread_id": thread_id,
                "checkpoint_ns": f"company:{user.company_id}"
            }
        }
        
        logger.info(
            "Invoking LangGraph pipeline",
            action="graph_invoke",
            metadata={"thread_id": thread_id}
        )
        
        start_time = time.time()
        result = await graph.ainvoke(initial_state, config=config)
        duration_ms = int((time.time() - start_time) * 1000)
        
        if result.get('error'):
            logger.error(
                f"Generation failed: {result['error']}",
                action="generation_failed",
                metadata={
                    "thread_id": thread_id,
                    "error": result['error'],
                    "duration_ms": duration_ms
                }
            )
            return {
                "success": False,
                "error": result['error'],
                "thread_id": thread_id
            }
        
        logger.info(
            f"Generation completed successfully",
            action="generation_complete",
            duration_ms=duration_ms,
            metadata={
                "thread_id": thread_id,
                "artifact_id": result.get('artifact_id')
            }
        )
        
        return {
            "success": True,
            "artifact_id": result.get('artifact_id'),
            "thread_id": thread_id
        }
        
    except Exception as e:
        logger.error(
            f"Generation exception: {str(e)}",
            action="generation_exception",
            metadata={
                "thread_id": thread_id,
                "error_type": type(e).__name__
            }
        )
        raise
```

---

## Database Query Logging

### Query Logger Wrapper

```python
import time
from core.logging_config import logger

class LoggedDatabase:
    """Database wrapper with query logging."""
    
    def __init__(self, pool):
        self.pool = pool
    
    async def execute(self, query: str, *args, action: str = None):
        """Execute query with logging."""
        
        start_time = time.time()
        
        try:
            result = await self.pool.execute(query, *args)
            duration_ms = int((time.time() - start_time) * 1000)
            
            if duration_ms > 1000:  # Warn on slow queries
                logger.warning(
                    f"Slow query detected: {duration_ms}ms",
                    action=action or "db_query_slow",
                    metadata={
                        "duration_ms": duration_ms,
                        "query_preview": query[:100]
                    }
                )
            else:
                logger.debug(
                    f"Query executed: {duration_ms}ms",
                    action=action or "db_query",
                    metadata={"duration_ms": duration_ms}
                )
            
            return result
            
        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            logger.error(
                f"Query failed: {str(e)}",
                action=action or "db_query_failed",
                metadata={
                    "duration_ms": duration_ms,
                    "query_preview": query[:100],
                    "error_type": type(e).__name__
                }
            )
            raise
    
    async def fetchone(self, query: str, *args, action: str = None):
        """Fetch one row with logging."""
        start_time = time.time()
        
        try:
            result = await self.pool.fetchrow(query, *args)
            duration_ms = int((time.time() - start_time) * 1000)
            
            logger.debug(
                f"Fetchone: {duration_ms}ms",
                action=action or "db_fetchone",
                metadata={
                    "duration_ms": duration_ms,
                    "found": result is not None
                }
            )
            
            return result
            
        except Exception as e:
            logger.error(
                f"Fetchone failed: {str(e)}",
                action=action or "db_fetchone_failed"
            )
            raise
```

---

## Checkpoint Debugging

### View Checkpoint History

```python
@router.get("/debug/checkpoints/{thread_id}")
async def get_checkpoint_history(
    thread_id: str,
    user = Depends(get_current_user)
):
    """Get all checkpoints for debugging."""
    
    checkpoints = await db.fetch(
        """
        select 
            checkpoint_id,
            parent_checkpoint_id,
            checkpoint->>'node' as node,
            metadata,
            created_at
        from langgraph_checkpoints
        where thread_id = $1
        order by checkpoint_id desc
        limit 50
        """,
        thread_id
    )
    
    return {
        "thread_id": thread_id,
        "checkpoint_count": len(checkpoints),
        "checkpoints": [dict(c) for c in checkpoints]
    }
```

---

## GCP Cloud Logging

### Log Queries

**Find all errors for a company:**
```
resource.type="cloud_run_revision"
jsonPayload.level="ERROR"
jsonPayload.company_id="your-company-uuid"
```

**Trace a specific request:**
```
jsonPayload.request_id="req_abc123"
```

**Track a LangGraph execution:**
```
jsonPayload.thread_id="company:keyword:abc123"
```

**Find slow nodes:**
```
jsonPayload.action="node_complete"
jsonPayload.duration_ms>5000
```

**Track LLM calls:**
```
jsonPayload.action=~"llm_.*"
```

---

## Performance Monitoring

### Add Timing Decorators

```python
def track_time(action: str):
    """Decorator to track function execution time."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start = time.time()
            try:
                result = await func(*args, **kwargs)
                duration_ms = int((time.time() - start) * 1000)
                logger.info(
                    f"{action} completed",
                    action=action,
                    duration_ms=duration_ms
                )
                return result
            except Exception as e:
                duration_ms = int((time.time() - start) * 1000)
                logger.error(
                    f"{action} failed: {str(e)}",
                    action=f"{action}_failed",
                    metadata={"duration_ms": duration_ms}
                )
                raise
        return wrapper
    return decorator

# Usage
@track_time("reddit_post")
async def post_comment(access_token, parent_id, text):
    # ... implementation
    pass
```

---

## Best Practices

### 1. Always Include Context
```python
# Good
logger.info(
    "Draft approved",
    action="draft_approved",
    metadata={
        "artifact_id": artifact_id,
        "subreddit": subreddit,
        "approved_by": user_id
    }
)

# Bad
logger.info("Draft approved")
```

### 2. Log State Transitions
```python
# Log every state change
logger.info(
    f"Artifact status changed: {old_status} -> {new_status}",
    action="status_change",
    metadata={
        "artifact_id": artifact_id,
        "old_status": old_status,
        "new_status": new_status
    }
)
```

### 3. Don't Log Sensitive Data
```python
# Good - Log without sensitive content
logger.info(
    "Draft composed",
    metadata={
        "draft_length": len(draft_text),
        "draft_preview": draft_text[:50]  # Only first 50 chars
    }
)

# Bad - Logs full content including potential PII
logger.info(f"Draft: {draft_text}")
```

### 4. Use Appropriate Log Levels
```python
# DEBUG: Detailed diagnostic info
logger.debug("RAG query vector computed", metadata={"dimensions": 1536})

# INFO: Normal operations
logger.info("Comment posted successfully")

# WARNING: Unexpected but handled
logger.warning("Rate limit approached", metadata={"remaining": 5})

# ERROR: Operation failed
logger.error("Failed to post comment", exc_info=True)
```

### 5. Log Errors with Context
```python
try:
    result = await risky_operation()
except Exception as e:
    logger.error(
        f"Operation failed: {str(e)}",
        action="operation_failed",
        metadata={
            "operation": "risky_operation",
            "input_params": {"param1": value1},
            "error_type": type(e).__name__
        },
        exc_info=True  # Includes full traceback
    )
    raise
```

---

## Next Steps

1. **M1**: Implement structured logging setup
2. **M2**: Add logging to all LangGraph nodes
3. **M3**: Add request tracking to API endpoints
4. **M4**: Set up GCP log alerts
5. **M5**: Create debugging runbook with common queries






