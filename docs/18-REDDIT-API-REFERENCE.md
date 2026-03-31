# Reddit API Reference

## Overview
This document provides essential Reddit API endpoints and conventions for the Reddit Reply Assistant.

---

## Core Concepts

### Listings

Many endpoints use the same protocol for pagination and filtering. These are called **Listings**.

**Common Parameters:**
- `after` / `before` - Fullname of item to use as anchor point (only one should be specified)
- `limit` - Maximum items to return in this slice (default: 25, max: 100)
- `count` - Number of items already seen in listing
- `show` - Optional; if `all` is passed, filters like "hide voted links" are disabled

**Pagination:**
- Don't use page numbers (content changes frequently)
- Response contains `after` and `before` fields (like "next" and "prev")
- Start by fetching first page without `after` and `count`
- Use `after` from response in next request
- Update `count` with number of items already fetched

### Modhashes

A modhash is a token for CSRF prevention. Can be obtained via `/api/me.json` or listing endpoints.

**Usage:**
- Preferred: Include `X-Modhash` custom HTTP header
- Not required when authenticated with OAuth

### Fullnames

A fullname combines a thing's type and unique ID (compact encoding of globally unique ID).

**Format:** `{type_prefix}_{id_in_base36}`

**Example:** `t3_15bfi0`

**Type Prefixes:**
- `t1_` - Comment
- `t2_` - Account
- `t3_` - Link (post)
- `t4_` - Message
- `t5_` - Subreddit
- `t6_` - Award

### Response Body Encoding

For legacy reasons, all JSON responses have:
- `<` replaced with `&lt;`
- `>` replaced with `&gt;`
- `&` replaced with `&amp;`

**Opt out:** Add `raw_json=1` parameter to request

---

## Authentication

### OAuth2 Flow

**Scopes needed for Reddit Reply Assistant:**
- `identity` - Access user's identity
- `read` - Read posts and comments
- `submit` - Submit links and comments
- `vote` - Vote on posts/comments (optional)

**Authorization URL:**
```
https://www.reddit.com/api/v1/authorize?
  client_id={CLIENT_ID}&
  response_type=code&
  state={STATE}&
  redirect_uri={REDIRECT_URI}&
  duration=permanent&
  scope=identity read submit vote
```

**Token Exchange:**
```http
POST https://www.reddit.com/api/v1/access_token
Authorization: Basic {base64(client_id:client_secret)}
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code={CODE}&
redirect_uri={REDIRECT_URI}
```

**Response:**
```json
{
  "access_token": "...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "scope": "identity read submit vote"
}
```

**Refresh Token:**
```http
POST https://www.reddit.com/api/v1/access_token
Authorization: Basic {base64(client_id:client_secret)}
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token&
refresh_token={REFRESH_TOKEN}
```

---

## Account Endpoints

### GET /api/v1/me

Return identity of the authenticated user.

**Scope:** `identity`

**Response:**
```json
{
  "name": "username",
  "id": "t2_xxxxx",
  "created_utc": 1234567890,
  "link_karma": 1234,
  "comment_karma": 5678,
  "total_karma": 6912,
  "is_gold": false,
  "is_mod": false
}
```

### GET /api/v1/me/karma

Return breakdown of subreddit karma.

**Scope:** `mysubreddits`

---

## Subreddit Endpoints

### GET /r/{subreddit}/about

Return information about the subreddit.

**Scope:** `read`

**Response includes:**
- Subscriber count
- Description
- Rules
- Public description
- Subreddit type (public, private, restricted)
- Over 18 status

### GET /r/{subreddit}/about/rules

Get rules for the subreddit.

**Scope:** `read`

**Response:**
```json
{
  "rules": [
    {
      "kind": "all",
      "short_name": "Be respectful",
      "description": "Treat others with respect...",
      "violation_reason": "Disrespectful behavior",
      "created_utc": 1234567890,
      "priority": 0
    }
  ]
}
```

### GET /r/{subreddit}/search

Search for posts in a subreddit.

**Parameters:**
- `q` - Search query (max 512 chars)
- `sort` - One of: `relevance`, `hot`, `top`, `new`, `comments`
- `t` - Time filter: `hour`, `day`, `week`, `month`, `year`, `all`
- `limit` - Max items (default: 25, max: 100)
- `after` / `before` - Pagination
- `restrict_sr` - Boolean, restrict to this subreddit only

**Scope:** `read`

---

## Post/Comment Endpoints

### POST /api/comment

Submit a new comment or reply.

**Scope:** `submit`

**Parameters:**
- `api_type` - String "json"
- `text` - Raw markdown body
- `thing_id` - Fullname of parent (Link or Comment)
- `uh` or `X-Modhash` - Modhash (not needed with OAuth)

**Response:**
```json
{
  "json": {
    "errors": [],
    "data": {
      "things": [
        {
          "kind": "t1",
          "data": {
            "id": "abc123",
            "name": "t1_abc123",
            "body": "Your comment text",
            "created_utc": 1234567890
          }
        }
      ]
    }
  }
}
```

**Important for Reddit Reply Assistant:**
- Use this endpoint to post replies to threads
- `thing_id` should be the fullname of the thread (`t3_xxxxx`)
- Check response for errors before marking as successful

### GET /api/info

Return listing of things by fullnames.

**Scope:** `read`

**Parameters:**
- `id` - Comma-separated list of fullnames
- `url` - A valid URL (alternative to id)

**Example:**
```
GET /api/info?id=t3_abc123,t3_def456
```

### GET /api/morechildren

Retrieve additional comments omitted from base comment tree.

**Scope:** `read`

**Parameters:**
- `link_id` - Fullname of the link
- `children` - Comma-delimited list of comment ID36s
- `limit_children` - Boolean
- `depth` - Maximum depth of subtrees

**Note:** Only make one request at a time to this endpoint.

---

## Search Endpoints

### GET /subreddits/search

Search for subreddits by title and description.

**Parameters:**
- `q` - Search query
- `sort` - One of: `relevance`, `activity`
- `limit` - Max items (default: 25, max: 100)

**Example:**
```
GET /subreddits/search?q=python&sort=relevance&limit=20
```

**Response:**
```json
{
  "kind": "Listing",
  "data": {
    "children": [
      {
        "kind": "t5",
        "data": {
          "display_name": "Python",
          "title": "Python Programming",
          "public_description": "...",
          "subscribers": 1234567,
          "active_user_count": 5678,
          "over18": false,
          "url": "/r/Python/"
        }
      }
    ]
  }
}
```

---

## Listing Endpoints

### GET /r/{subreddit}/new

Get new posts from a subreddit.

**Parameters:**
- Standard listing parameters (after, before, count, limit)

**Scope:** `read`

### GET /r/{subreddit}/hot

Get hot posts from a subreddit.

**Parameters:**
- Standard listing parameters
- `g` - Geolocation filter (optional)

**Scope:** `read`

### GET /r/{subreddit}/top

Get top posts from a subreddit.

**Parameters:**
- Standard listing parameters
- `t` - Time filter: `hour`, `day`, `week`, `month`, `year`, `all`

**Scope:** `read`

---

## Rate Limiting

### Standard Rate Limits

- **60 requests per minute** per OAuth client
- **600 requests per 10 minutes** per OAuth client
- Use `X-Ratelimit-*` headers to track:
  - `X-Ratelimit-Remaining` - Requests remaining
  - `X-Ratelimit-Used` - Requests used
  - `X-Ratelimit-Reset` - Seconds until reset

### Best Practices

1. **Respect rate limits** - Wait when approaching limit
2. **Use exponential backoff** for 429 responses
3. **Batch requests** where possible
4. **Cache responses** when appropriate
5. **Use User-Agent** header: `{platform}:{app_id}:{version} (by /u/{username})`

---

## Error Handling

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid/expired token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `429` - Too Many Requests (rate limited)
- `500` - Server Error
- `503` - Service Unavailable

### Error Response Format

```json
{
  "message": "Forbidden",
  "error": 403
}
```

Or for API-specific errors:

```json
{
  "json": {
    "errors": [
      ["RATELIMIT", "you are doing that too much. try again in 5 minutes.", "ratelimit"]
    ]
  }
}
```

---

## Implementation Guide for Reddit Reply Assistant

### Subreddit Discovery (`FetchSubreddits` node)

```python
import asyncpraw

async def search_subreddits(keyword: str, limit: int = 20):
    async with asyncpraw.Reddit(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        user_agent=USER_AGENT
    ) as reddit:
        subreddits = []
        async for subreddit in reddit.subreddits.search(keyword, limit=limit):
            subreddits.append({
                "name": subreddit.display_name,
                "title": subreddit.title,
                "description": subreddit.public_description,
                "subscribers": subreddit.subscribers,
                "active_users": getattr(subreddit, 'active_user_count', 0),
                "over18": subreddit.over18,
                "url": subreddit.url
            })
        return subreddits
```

### Fetch Subreddit Rules (`FetchRules` node)

```python
async def fetch_rules(subreddit_name: str):
    async with asyncpraw.Reddit(...) as reddit:
        subreddit = await reddit.subreddit(subreddit_name)
        
        rules = []
        async for rule in subreddit.rules:
            rules.append({
                "short_name": rule.short_name,
                "description": rule.description,
                "kind": rule.kind,  # "link", "comment", "all"
                "violation_reason": rule.violation_reason
            })
        
        return {
            "rules": rules,
            "description": subreddit.description
        }
```

### Search Threads (`FetchThreads` node)

```python
async def search_threads(subreddit_name: str, keyword: str, limit: int = 50):
    async with asyncpraw.Reddit(...) as reddit:
        subreddit = await reddit.subreddit(subreddit_name)
        
        threads = []
        async for submission in subreddit.search(
            keyword,
            sort='new',
            time_filter='week',
            limit=limit
        ):
            # Filter for questions/help posts
            if is_question_post(submission):
                threads.append({
                    "reddit_id": submission.id,
                    "fullname": submission.name,  # t3_xxxxx
                    "title": submission.title,
                    "body": submission.selftext,
                    "url": submission.url,
                    "permalink": submission.permalink,
                    "author": submission.author.name if submission.author else "[deleted]",
                    "created_utc": submission.created_utc,
                    "score": submission.score,
                    "num_comments": submission.num_comments
                })
        
        return threads

def is_question_post(submission) -> bool:
    """Check if submission is a question/help post."""
    title_lower = submission.title.lower()
    return (
        '?' in submission.title
        or any(word in title_lower for word in [
            'how', 'what', 'why', 'help', 'question', 'advice', 'need'
        ])
        or (submission.link_flair_text and 
            submission.link_flair_text in ['Question', 'Help', 'Discussion'])
    )
```

### Post Comment (Approve & Post Flow)

```python
async def post_comment(
    access_token: str,
    parent_fullname: str,  # e.g., t3_abc123
    comment_text: str
) -> dict:
    """Post a comment to Reddit."""
    import httpx
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://oauth.reddit.com/api/comment",
            headers={
                "Authorization": f"Bearer {access_token}",
                "User-Agent": "mentions/1.0"
            },
            data={
                "api_type": "json",
                "text": comment_text,
                "thing_id": parent_fullname
            }
        )
        
        if response.status_code != 200:
            raise Exception(f"Failed to post comment: {response.status_code}")
        
        result = response.json()
        
        # Check for errors
        if result.get('json', {}).get('errors'):
            errors = result['json']['errors']
            raise Exception(f"Reddit API error: {errors}")
        
        # Extract comment data
        things = result['json']['data']['things']
        if things:
            comment_data = things[0]['data']
            return {
                "comment_id": comment_data['id'],
                "fullname": comment_data['name'],
                "permalink": comment_data.get('permalink'),
                "created_utc": comment_data.get('created_utc')
            }
        
        raise Exception("No comment data returned")
```

### Verify Comment Visibility

```python
async def verify_comment(permalink: str, expected_text_snippet: str) -> bool:
    """
    Verify comment is visible by fetching it without authentication.
    Returns True if visible, False if removed/shadow-banned.
    """
    import httpx
    
    # Use logged-out request
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://www.reddit.com{permalink}.json",
            headers={"User-Agent": "mentions/1.0"}
        )
        
        if response.status_code != 200:
            return False
        
        data = response.json()
        
        # Search for comment in response
        # (Reddit returns thread + comments in nested structure)
        def find_comment(obj):
            if isinstance(obj, dict):
                if obj.get('body') and expected_text_snippet in obj['body']:
                    return True
                for value in obj.values():
                    if find_comment(value):
                        return True
            elif isinstance(obj, list):
                for item in obj:
                    if find_comment(item):
                        return True
            return False
        
        return find_comment(data)
```

### Refresh Access Token

```python
async def refresh_access_token(
    client_id: str,
    client_secret: str,
    refresh_token: str
) -> dict:
    """Refresh OAuth access token."""
    import httpx
    import base64
    
    # Create basic auth header
    credentials = f"{client_id}:{client_secret}"
    encoded = base64.b64encode(credentials.encode()).decode()
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://www.reddit.com/api/v1/access_token",
            headers={
                "Authorization": f"Basic {encoded}",
                "User-Agent": "mentions/1.0"
            },
            data={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token
            }
        )
        
        if response.status_code != 200:
            raise Exception(f"Failed to refresh token: {response.status_code}")
        
        return response.json()
```

---

## Common Pitfalls

### 1. Rate Limiting
**Issue:** Hitting 429 errors  
**Solution:** Implement exponential backoff, respect `X-Ratelimit-*` headers

### 2. Modhash with OAuth
**Issue:** Including modhash when using OAuth  
**Solution:** Don't send modhash with OAuth requests

### 3. Missing User-Agent
**Issue:** Requests blocked or rate-limited more aggressively  
**Solution:** Always include descriptive User-Agent

### 4. Not Checking for Errors
**Issue:** Assuming 200 response means success  
**Solution:** Check `json.errors` array in response

### 5. Hardcoded Delays
**Issue:** Using `time.sleep(X)` between all requests  
**Solution:** Use rate limit headers to determine when to wait

### 6. Shadow Bans
**Issue:** Comments post successfully but aren't visible  
**Solution:** Implement verification step with logged-out request

---

## Testing

### Test Subreddit
Create a private test subreddit for development:
- `/r/mentions_test_dev` (or similar)
- Set as private or restricted
- Use for all staging/dev posts

### Staging Restrictions
- **Never post to production subreddits from staging**
- Set `ALLOW_POSTS=false` in non-prod environments
- Use test subreddit whitelist in staging

---

## References

- [Official Reddit API Documentation](https://www.reddit.com/dev/api/)
- [OAuth2 Documentation](https://github.com/reddit-archive/reddit/wiki/OAuth2)
- [asyncpraw Documentation](https://asyncpraw.readthedocs.io/)
- [Rate Limiting Details](https://github.com/reddit-archive/reddit/wiki/API#rules)

---

## Next Steps

Implement these endpoints in:
1. **reddit/client.py** - Core Reddit API wrapper
2. **reddit/verify.py** - Comment verification logic
3. **graph/nodes/** - Individual LangGraph nodes for subreddit/thread fetching
4. **workers/cloud_tasks_handlers.py** - Posting and verification handlers






