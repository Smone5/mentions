# Troubleshooting Guide

Common issues and solutions.

---

## Database Issues

### Cannot connect to Supabase
**Symptoms**: `Connection refused` or `timeout`

**Solutions**:
1. Check `DB_CONN` string format
2. Verify Supabase project is active
3. Check IP whitelist settings
4. Test with `psql`:
   ```bash
   psql "postgresql://..."
   ```

### RLS policy violations
**Symptoms**: `new row violates row-level security policy`

**Solutions**:
1. Verify user has `company_id` set
2. Check RLS policies are enabled
3. Confirm using correct Supabase client (not service role)
4. Test query directly:
   ```sql
   SELECT d.*, a.company_id 
   FROM drafts d
   JOIN artifacts a ON d.artifact_id = a.id
   WHERE a.company_id = 'xxx';
   ```

---

## Reddit Integration

### OAuth flow fails
**Symptoms**: Redirect doesn't work, "invalid redirect_uri"

**Solutions**:
1. Check redirect URI matches exactly (including trailing slash)
2. Verify Reddit app type is "web app"
3. Check client_id and client_secret
4. Confirm Reddit app not suspended

### Posts not appearing
**Symptoms**: Post seems successful but not visible

**Solutions**:
1. Check if account is shadow-banned
2. Verify subreddit rules allow posts
3. Check account age/karma requirements
4. Wait 5 minutes (Reddit delay)
5. Check verification task logs

### Rate limit errors
**Symptoms**: `429 Too Many Requests`

**Solutions**:
1. Check posts per day/hour limits
2. Verify Cloud Tasks queue configuration
3. Confirm MIN_MINUTES_BETWEEN_POSTS enforced
4. Review `rate_limiter.py` logs

---

## LangGraph Issues

### State not persisting
**Symptoms**: Pipeline restarts lose state

**Solutions**:
1. Confirm `PostgresSaver` configured
2. Check `langgraph_checkpoints` table exists
3. Verify `thread_id` is unique
4. Check database connection in checkpointer

### Judge always rejects
**Symptoms**: All subreddits/drafts rejected

**Solutions**:
1. Check LLM temperature (should be 0.2)
2. Review judge prompt
3. Check OpenAI API key valid
4. Test judge prompt manually
5. Review judge logs for patterns

### Pipeline hangs
**Symptoms**: Generation never completes

**Solutions**:
1. Check for infinite loops in conditional edges
2. Verify all nodes return state
3. Check for unhandled exceptions
4. Review LangGraph logs
5. Add timeout to graph execution

---

## Cloud Run / Deployment

### Health check fails
**Symptoms**: Service won't deploy, "unhealthy"

**Solutions**:
1. Check `/health` endpoint responds
2. Verify port 8000 exposed
3. Check container logs for startup errors
4. Confirm environment variables set
5. Test Docker image locally

### Cold starts slow
**Symptoms**: First request takes >10s

**Solutions**:
1. Set `min-instances=1` in production
2. Reduce Docker image size
3. Optimize imports (lazy load)
4. Use Cloud Run warming requests

### Secrets not accessible
**Symptoms**: `Permission denied` accessing secrets

**Solutions**:
1. Verify service account has `secretAccessor` role
2. Check secret exists and has version
3. Confirm secret name matches exactly
4. Test with `gcloud secrets versions access`

---

## Frontend Issues

### "Network error" on API calls
**Symptoms**: All API calls fail

**Solutions**:
1. Check `NEXT_PUBLIC_API_URL` set correctly
2. Verify backend is running
3. Check CORS settings in FastAPI
4. Confirm JWT token in headers
5. Check browser console for errors

### Supabase Auth not working
**Symptoms**: Can't log in, token invalid

**Solutions**:
1. Verify `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`
2. Check redirect URLs configured in Supabase
3. Clear browser cookies/localStorage
4. Check Supabase project not paused
5. Verify email confirmation (if required)

---

## LLM / OpenAI Issues

### API key invalid
**Symptoms**: `401 Unauthorized`

**Solutions**:
1. Check `OPENAI_API_KEY` is correct
2. Verify key hasn't expired
3. Check billing is active
4. Confirm key has correct permissions

### Rate limit exceeded
**Symptoms**: `429 Rate limit exceeded`

**Solutions**:
1. Implement exponential backoff
2. Reduce concurrent requests
3. Check quota limits
4. Consider caching responses

### Embeddings fail
**Symptoms**: RAG search doesn't work

**Solutions**:
1. Check embedding model name correct
2. Verify text length within limits
3. Check pgvector extension installed
4. Test embedding generation manually

---

## Testing Issues

### Tests fail in CI but pass locally
**Symptoms**: GitHub Actions tests fail

**Solutions**:
1. Check test dependencies installed
2. Verify database available in CI
3. Check environment variables set
4. Review CI logs for specifics
5. Run tests with same Python version

### Flaky tests
**Symptoms**: Tests randomly fail

**Solutions**:
1. Add explicit waits for async operations
2. Use transactions for test isolation
3. Mock external services
4. Check for race conditions
5. Add retries for network calls

---

## Performance Issues

### Draft generation slow (>2 min)
**Symptoms**: Users wait too long

**Solutions**:
1. Check LLM API latency
2. Verify Reddit API responding
3. Check database query performance
4. Review LangGraph logs
5. Consider caching subreddit data

### Database queries slow
**Symptoms**: High latency on `/api/drafts`

**Solutions**:
1. Add indexes:
   ```sql
   CREATE INDEX idx_drafts_company_id ON drafts(company_id);
   CREATE INDEX idx_drafts_status ON drafts(status);
   ```
2. Check Supabase connection pool
3. Optimize query (avoid N+1)
4. Add pagination
5. Review execution plan

---

## Common Error Messages

### "Draft not approved"
**Cause**: Trying to post unapproved draft  
**Fix**: Ensure draft status is "approved" and `approved_by` is set

### "Rate limit exceeded"
**Cause**: Posting too frequently  
**Fix**: Wait until next eligible time, check rate limits

### "Draft contains links"
**Cause**: Link detected in draft body  
**Fix**: Remove all links/URLs from draft

### "Subreddit rejected"
**Cause**: LLM judge rejected subreddit  
**Fix**: Review judge reason, try different subreddit

### "Company isolation violation"
**Cause**: Accessing data from different company  
**Fix**: Verify company_id filter in all queries

---

## Debug Commands

```bash
# Check logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Check database
psql $DB_CONN -c "SELECT d.*, a.status FROM drafts d JOIN artifacts a ON d.artifact_id = a.id WHERE a.status='new' LIMIT 5;"

# Test endpoint
curl -H "Authorization: Bearer xxx" https://api.mentions.ai/health

# Check Redis cache (if using)
redis-cli KEYS "*"

# Check Cloud Tasks queue
gcloud tasks queues describe reddit-posts-default --location=us-central1
```

---

## When All Else Fails

1. Check [24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md) for debugging strategies
2. Review recent commits for breaking changes
3. Compare with working environment (dev vs staging)
4. Check GCP status page
5. Check Reddit status
6. Check OpenAI status
7. Rollback to last known good version

---

## Getting Help

**Before asking**:
1. Check this troubleshooting guide
2. Review relevant documentation
3. Check logs for error messages
4. Try to reproduce in dev environment
5. Gather context (logs, error messages, steps to reproduce)

**When asking**:
- Provide exact error message
- Include relevant logs
- Describe what you tried
- Share code snippet if relevant
- Specify environment (dev/staging/prod)

**Reference**: [24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md), [23-OBSERVABILITY.md](./23-OBSERVABILITY.md)

