# Code Templates

Reusable code scaffolds for common patterns.

---

## FastAPI Endpoint

```python
# api/my_resource.py
from fastapi import APIRouter, Depends, HTTPException
from core.auth import get_current_user
from models.requests import MyRequest
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/my-resource")
async def create_resource(
    request: MyRequest,
    user = Depends(get_current_user)
):
    """Create a new resource."""
    try:
        # Validate
        if not request.name:
            raise HTTPException(status_code=400, detail="Name required")
        
        # Create
        resource_id = await db.execute(
            """
            INSERT INTO my_resources (id, company_id, name, created_at)
            VALUES ($1, $2, $3, NOW())
            RETURNING id
            """,
            str(uuid.uuid4()),
            user.company_id,
            request.name
        )
        
        logger.info("resource_created", resource_id=resource_id, company_id=user.company_id)
        
        return {"success": True, "id": resource_id}
        
    except Exception as e:
        logger.error("resource_creation_failed", error=str(e), company_id=user.company_id)
        raise HTTPException(status_code=500, detail=str(e))
```

---

## Next.js Page

```tsx
// app/my-page/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function MyPage() {
  const router = useRouter()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  
  useEffect(() => {
    fetchData()
  }, [])
  
  const fetchData = async () => {
    try {
      const response = await fetch('/api/my-resource')
      const data = await response.json()
      setData(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }
  
  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error}</div>
  
  return (
    <div className="container mx-auto px-4 py-6">
      <h1 className="text-3xl font-bold mb-6">My Page</h1>
      {/* Content */}
    </div>
  )
}
```

---

## LangGraph Node

```python
# graph/nodes/my_node.py
from graph.state import GenerateState
import logging

logger = logging.getLogger(__name__)

async def my_node(state: GenerateState) -> GenerateState:
    """
    Do something in the pipeline.
    """
    try:
        # Get inputs from state
        input_value = state["input_field"]
        
        # Process
        result = await process(input_value)
        
        # Update state
        state["output_field"] = result
        
        logger.info(
            "node_completed",
            node="my_node",
            company_id=state["company_id"]
        )
        
        return state
        
    except Exception as e:
        logger.error(
            "node_failed",
            node="my_node",
            error=str(e),
            company_id=state["company_id"]
        )
        state["error"] = f"My node failed: {e}"
        return state
```

---

## React Component

```tsx
// components/MyComponent.tsx
interface Props {
  title: string
  onAction?: () => void
  disabled?: boolean
}

export function MyComponent({ title, onAction, disabled = false }: Props) {
  const [state, setState] = useState(false)
  
  const handleClick = () => {
    if (!disabled && onAction) {
      onAction()
    }
  }
  
  return (
    <div className="p-4 border rounded">
      <h3 className="font-bold mb-2">{title}</h3>
      <button
        onClick={handleClick}
        disabled={disabled}
        className="px-4 py-2 bg-blue-600 text-white rounded disabled:opacity-50"
      >
        Action
      </button>
    </div>
  )
}
```

---

## Database Query

```python
# With company isolation (RLS)
async def get_resources(company_id: str):
    """Get resources for company."""
    return await db.fetch(
        """
        SELECT * FROM my_resources
        WHERE company_id = $1
        ORDER BY created_at DESC
        """,
        company_id
    )

# With pagination
async def get_paginated(company_id: str, limit: int = 20, offset: int = 0):
    """Get paginated resources."""
    resources = await db.fetch(
        "SELECT * FROM my_resources WHERE company_id = $1 LIMIT $2 OFFSET $3",
        company_id, limit, offset
    )
    
    total = await db.fetchval(
        "SELECT COUNT(*) FROM my_resources WHERE company_id = $1",
        company_id
    )
    
    return {"resources": resources, "total": total}
```

---

## Test

```python
# tests/test_my_feature.py
import pytest

@pytest.mark.asyncio
async def test_my_feature(test_company, test_user):
    """Test my feature works correctly."""
    # Arrange
    resource = await create_test_resource(test_company.id)
    
    # Act
    result = await do_something(resource.id)
    
    # Assert
    assert result["success"] == True
    assert result["data"] is not None
    
    # Cleanup
    await delete_test_resource(resource.id)
```

---

## Cloud Task

```python
# tasks/my_task.py
from google.cloud import tasks_v2
from core.config import settings

async def enqueue_my_task(resource_id: str, delay_seconds: int = 0):
    """Enqueue background task."""
    task_client = tasks_v2.CloudTasksClient()
    
    queue_path = task_client.queue_path(
        settings.GOOGLE_PROJECT_ID,
        settings.GOOGLE_LOCATION,
        "my-task-queue"
    )
    
    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": f"{settings.API_URL}/internal/my-task/{resource_id}",
        }
    }
    
    if delay_seconds > 0:
        schedule_time = timestamp_pb2.Timestamp()
        schedule_time.FromDatetime(datetime.now() + timedelta(seconds=delay_seconds))
        task["schedule_time"] = schedule_time
    
    return task_client.create_task(parent=queue_path, task=task)


@router.post("/internal/my-task/{resource_id}")
async def my_task_handler(resource_id: str):
    """Handle task execution."""
    try:
        await process_task(resource_id)
        return {"success": True}
    except Exception as e:
        logger.error("task_failed", resource_id=resource_id, error=str(e))
        raise HTTPException(status_code=500, detail=str(e))
```

---

## Pydantic Model

```python
# models/requests.py
from pydantic import BaseModel, Field
from typing import Optional

class CreateResourceRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    active: bool = True
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "My Resource",
                "description": "Optional description",
                "active": True
            }
        }
```

**Reference**: [30-CODE-CONVENTIONS.md](./30-CODE-CONVENTIONS.md), [20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)

