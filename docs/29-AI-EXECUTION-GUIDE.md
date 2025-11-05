# AI Execution Guide

**For AI Agents**: How to read and execute this documentation effectively.

---

## How to Use These Docs

### 1. Start with Quick Start
Read **[00-QUICK-START.md](./00-QUICK-START.md)** first for 30-second overview.

### 2. Understand Non-Negotiables
Read **[22-HARD-RULES.md](./22-HARD-RULES.md)** - These are ABSOLUTE. No exceptions.

### 3. Follow Implementation Order
Read **[31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md)** - This shows exact dependency graph.

### 4. Execute Milestones Sequentially
- M1 → M2 → M3 → M4 → M5
- Complete each milestone fully before moving to next
- Verify after each task

---

## Decision Trees

### "Which document do I need?"

**Setting up environment?**
→ [02-ENVIRONMENT-SETUP.md](./02-ENVIRONMENT-SETUP.md) or [28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)

**Creating database schema?**
→ [03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md)

**Building generation pipeline?**
→ [10-LANGGRAPH-FLOW.md](./10-LANGGRAPH-FLOW.md)

**Implementing posting?**
→ [12-POSTING-FLOW.md](./12-POSTING-FLOW.md)
→ **CRITICAL**: Read [22-HARD-RULES.md](./22-HARD-RULES.md) first

**Creating UI?**
→ [14-UI-SPECIFICATIONS.md](./14-UI-SPECIFICATIONS.md) and [25-FRONTEND-PAGES.md](./25-FRONTEND-PAGES.md)

**Need API spec?**
→ [21-API-ENDPOINTS.md](./21-API-ENDPOINTS.md)

**Need code template?**
→ [32-CODE-TEMPLATES.md](./32-CODE-TEMPLATES.md)

**Stuck on error?**
→ [33-TROUBLESHOOTING.md](./33-TROUBLESHOOTING.md)

---

## Execution Patterns

### Pattern 1: New Feature
1. Check [31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md) for dependencies
2. Read relevant milestone document (M1-M5)
3. Read implementation guide (10-16)
4. Find code template in [32-CODE-TEMPLATES.md](./32-CODE-TEMPLATES.md)
5. Implement
6. Test (see [15-TESTING-PLAN.md](./15-TESTING-PLAN.md))

### Pattern 2: Fixing Bug
1. Check [33-TROUBLESHOOTING.md](./33-TROUBLESHOOTING.md)
2. Check [24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md)
3. Reproduce locally
4. Fix
5. Add test to prevent regression

### Pattern 3: Refactoring
1. Read [30-CODE-CONVENTIONS.md](./30-CODE-CONVENTIONS.md)
2. Check [20-REPOSITORY-STRUCTURE.md](./20-REPOSITORY-STRUCTURE.md)
3. Refactor
4. Ensure all tests still pass

---

## Handling Ambiguity

### When Instructions Are Unclear

**DON'T**: Guess or make assumptions  
**DO**: 
1. Check related documents for context
2. Look for similar examples in codebase
3. Follow established patterns
4. Ask for clarification if truly ambiguous

### When Multiple Approaches Exist

**Prefer**:
1. Approach documented in these guides
2. Approach that enforces hard rules
3. Simpler approach
4. Approach with better error handling

---

## Common Patterns

### File Naming
- Backend: `snake_case.py`
- Frontend: `PascalCase.tsx` (components), `camelCase.ts` (utils)

### Import Organization
```python
# Backend
import standard_library
import third_party
from core import local_module
```

```typescript
// Frontend
import { external } from 'external-package'
import { local } from '@/local'
```

### Error Handling
```python
# Always log errors with context
try:
    await risky_operation()
except Exception as e:
    logger.error(
        "operation_failed",
        operation="risky_operation",
        error=str(e),
        context={...}
    )
    raise
```

---

## Verification Steps

After implementing any feature:
1. **Does it work?** - Test locally
2. **Does it follow hard rules?** - Check [22-HARD-RULES.md](./22-HARD-RULES.md)
3. **Is it tested?** - Add tests
4. **Is it logged?** - Add structured logging
5. **Is it documented?** - Update docs if needed

---

## Red Flags 🚩

**Stop immediately if you see**:
- Posting without approval check
- Plain text credentials
- Links in draft body
- Bypassing LLM judge
- No company_id filter (RLS violation)
- Global shared Reddit client
- ALLOW_POSTS=true in dev/staging

**These violate hard rules and could cause bans.**

---

## Workflow Example

**Task**: "Implement draft approval endpoint"

1. **Check order**: [31-IMPLEMENTATION-ORDER.md](./31-IMPLEMENTATION-ORDER.md) → Phase 3, Task 3.1
2. **Read milestone**: [M3-REVIEW-UI.md](./M3-REVIEW-UI.md) → Task 3.1
3. **Check hard rules**: [22-HARD-RULES.md](./22-HARD-RULES.md) → Rule 1 (approval), Rule 6 (rate limits)
4. **Find template**: [32-CODE-TEMPLATES.md](./32-CODE-TEMPLATES.md) → FastAPI endpoint template
5. **Implement**:
   ```python
   @router.post("/drafts/{draft_id}/approve")
   async def approve_draft(draft_id, user = Depends(get_current_user)):
       # Check rate limits (Rule 6)
       is_eligible, reason = await check_post_eligibility(...)
       if not is_eligible:
           raise HTTPException(429, detail=reason)
       
       # Update draft
       await db.execute("UPDATE drafts SET status='approved', approved_by=$1 WHERE id=$2", user.id, draft_id)
       
       # Enqueue posting task
       task_id = await enqueue_post_task(draft_id)
       
       return {"success": True, "task_id": task_id}
   ```
6. **Test**: Add test to `tests/integration/test_drafts.py`
7. **Verify**: All hard rules enforced

---

## Key Principles for AI Agents

1. **Follow the order** - Dependencies matter
2. **Enforce hard rules** - Always, no exceptions
3. **Test everything** - Especially hard rules
4. **Log with context** - Make debugging possible
5. **Verify frequently** - Don't assume it works
6. **Ask when unclear** - Better than guessing wrong

---

## Success Metrics

You're doing well if:
- ✅ Following implementation order
- ✅ All hard rules enforced
- ✅ Tests passing
- ✅ Logs include context
- ✅ No shortcuts taken

You need to course-correct if:
- ❌ Skipping ahead in implementation order
- ❌ Hard rules violated
- ❌ No tests for critical code
- ❌ Errors without context
- ❌ Taking shortcuts

---

## Final Checklist

Before marking any task complete:
- [ ] Code works locally
- [ ] All hard rules enforced
- [ ] Tests added and passing
- [ ] Structured logging in place
- [ ] Error handling graceful
- [ ] Company isolation verified (if applicable)
- [ ] Documentation updated (if needed)

**Remember**: These docs exist to help you build a production-ready system that won't get banned from Reddit. Follow them carefully.

