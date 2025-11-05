# Posting & Verification Flow

Complete guide for posting approved drafts to Reddit and verifying visibility.

---

## Flow

```
Human Approves → Check Rate Limits → Enqueue Task → Post to Reddit → Schedule Verification → Verify Visible → Update Status
```

---

## Implementation

### Posting Service

```python
# services/post.py (see M3-REVIEW-UI.md for complete implementation)

async def post_to_reddit(draft_id: str) -> dict:
    """
    Post approved draft to Reddit.
    Enforces: Rule 1 (approval), Rule 2 (no links), Rule 6 (rate limits), Rule 10 (environment)
    """
    draft = await get_draft(draft_id)
    
    # Rule 1: Check approval
    if draft["status"] != "approved":
        raise Exception("Draft not approved")
    
    # Rule 10: Check environment
    if settings.ENV != "prod" or not settings.ALLOW_POSTS:
        return await mock_post(draft)
    
    # Rule 2: Validate no links
    is_valid, reason = validate_no_links(draft["body"])
    if not is_valid:
        raise Exception(f"Draft contains links: {reason}")
    
    # Rule 6: Check rate limits
    is_eligible, reason = await check_post_eligibility(
        draft["company_id"], draft["reddit_account_id"], draft["subreddit"]
    )
    if not is_eligible:
        raise Exception(reason)
    
    # Post to Reddit
    reddit_client = await get_reddit_client(draft["company_id"], draft["reddit_account_id"])
    result = await reddit_client.comment(draft["thread_id"], draft["body"])
    
    # Create post record
    post_id = await create_post_record(draft_id, result)
    
    # Rule 8: Schedule verification
    await schedule_verification_task(post_id, delay=60)
    
    return {"success": True, "post_id": post_id, "permalink": result["permalink"]}
```

### Verification

```python
# tasks/verify_post.py (see M3-REVIEW-UI.md for complete implementation)

async def verify_post_visibility(post_id: str):
    """
    Verify post is visible on Reddit (not shadow-banned).
    """
    post = await get_post(post_id)
    
    # Wait for Reddit to process
    await asyncio.sleep(30)
    
    # Fetch as anonymous user
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://www.reddit.com/comments/{post['reddit_post_id']}.json",
            headers={"User-Agent": "Mozilla/5.0"}
        )
    
    if response.status_code == 404:
        await mark_post_removed(post_id)
        await notify_user(post_id, "Post appears to be removed")
        return {"visible": False}
    
    data = response.json()
    comment = data[1]["data"]["children"][0]["data"]
    
    if comment.get("removed") or comment.get("spam"):
        await mark_post_removed(post_id)
        return {"visible": False}
    
    await mark_post_verified(post_id)
    return {"visible": True}
```

---

## Cloud Tasks Integration

```python
# services/tasks.py
async def enqueue_post_task(draft_id: str):
    """Enqueue posting task with rate limiting."""
    draft = await get_draft(draft_id)
    
    # Calculate delay based on last post
    last_post_time = await get_last_post_time(draft["reddit_account_id"])
    delay_seconds = calculate_delay(last_post_time)
    
    # Create task
    task_client = tasks_v2.CloudTasksClient()
    queue_path = get_queue_path(draft["reddit_account_id"])
    
    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": f"{settings.API_URL}/internal/post/{draft_id}"
        },
        "schedule_time": timestamp_pb2.Timestamp().FromDatetime(
            datetime.now() + timedelta(seconds=delay_seconds)
        )
    }
    
    return task_client.create_task(parent=queue_path, task=task)
```

---

## Verification Checklist

- [ ] All hard rules enforced (1, 2, 6, 8, 10)
- [ ] Posts successfully in production
- [ ] Mocks correctly in dev/staging
- [ ] Verification detects removed posts
- [ ] Users notified of removal

**Reference**: [M3-REVIEW-UI.md](./M3-REVIEW-UI.md), [22-HARD-RULES.md](./22-HARD-RULES.md)

