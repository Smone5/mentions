# Code Conventions

Coding standards for backend and frontend.

---

## Python (Backend)

### Style
- **PEP 8** compliant
- **Type hints** for all functions
- **Docstrings** for public functions
- **Line length**: 100 characters

### Naming
```python
# Files
my_module.py

# Functions/variables
def calculate_score():
    user_id = "123"

# Classes
class RedditClient:
    pass

# Constants
MAX_POSTS_PER_DAY = 10
```

### Imports
```python
# Standard library
import asyncio
from datetime import datetime

# Third party
from fastapi import APIRouter
import structlog

# Local
from core.config import settings
from services.post import post_to_reddit
```

### Async
```python
# Prefer async/await
async def fetch_data():
    result = await db.fetch("SELECT * FROM users")
    return result
```

### Error Handling
```python
# Always log with context
try:
    await risky_operation()
except Exception as e:
    logger.error(
        "operation_failed",
        operation="risky_operation",
        error=str(e),
        user_id=user_id
    )
    raise HTTPException(status_code=500, detail=str(e))
```

---

## TypeScript (Frontend)

### Style
- **Strict mode** enabled
- **Functional components** with hooks
- **Named exports** preferred
- **Line length**: 100 characters

### Naming
```typescript
// Files
MyComponent.tsx
useMyHook.ts
apiClient.ts

// Variables/functions
const userId = "123"
function calculateScore() {}

// Components
export function MyComponent() {}

// Types/Interfaces
interface User {
  id: string
  email: string
}
```

### Imports
```typescript
// External
import { useState } from 'react'
import { format } from 'date-fns'

// Internal
import { Button } from '@/components/ui/button'
import { apiClient } from '@/lib/api'
```

### Components
```tsx
// Functional with TypeScript
interface Props {
  userId: string
  onSave?: () => void
}

export function UserCard({ userId, onSave }: Props) {
  const [loading, setLoading] = useState(false)
  
  return (
    <div className="p-4 border rounded">
      {/* Component content */}
    </div>
  )
}
```

---

## Database

### Queries
```python
# Use parameterized queries (prevent SQL injection)
await db.execute(
    "SELECT * FROM users WHERE company_id = $1",
    company_id
)

# NOT this
await db.execute(f"SELECT * FROM users WHERE company_id = '{company_id}'")
```

### Transactions
```python
# Use transactions for multi-step operations
async with db.transaction():
    await db.execute("INSERT INTO drafts ...")
    await db.execute("INSERT INTO training_events ...")
```

---

## Logging

```python
# Structured logging with context
logger.info(
    "draft_approved",
    draft_id=draft_id,
    company_id=company_id,
    user_id=user_id,
    subreddit=subreddit
)

# NOT this
logger.info(f"Draft {draft_id} approved")
```

---

## Testing

```python
# Test file naming
test_my_module.py

# Test function naming
def test_user_can_approve_draft():
    pass

# Use fixtures
@pytest.fixture
async def test_user():
    user = await create_user()
    yield user
    await delete_user(user.id)
```

---

## Git Commits

```
feat: add draft approval endpoint
fix: prevent double-posting
docs: update API reference
test: add rate limit tests
refactor: extract validation logic
```

---

## Documentation

```python
def post_to_reddit(draft_id: str) -> dict:
    """
    Post approved draft to Reddit.
    
    Args:
        draft_id: UUID of draft to post
        
    Returns:
        dict with post_id and permalink
        
    Raises:
        Exception if draft not approved or rate limited
    """
    pass
```

**Reference**: [20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)



