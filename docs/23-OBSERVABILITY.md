# Observability - Logging, Metrics, Alerts

Complete observability strategy for production monitoring.

---

## Structured Logging

See complete implementation in [24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md).

**Key Fields**:
- `request_id` - Track request across services
- `company_id` - Filter logs by company
- `reddit_account_id` - Track account activity
- `action` - What happened
- `outcome` - Success/failure
- `duration_ms` - Performance tracking

**Example**:
```python
logger.info(
    "draft_approved",
    draft_id=draft_id,
    company_id=company_id,
    user_id=user_id,
    subreddit=subreddit,
    risk=risk_level
)
```

---

## Metrics Collection

**GCP Cloud Monitoring**:
```python
# services/metrics.py
def record_metric(metric_name, value, labels=None):
    """Record custom metric in GCP."""
    series = monitoring_v3.TimeSeries()
    series.metric.type = f"custom.googleapis.com/mentions/{metric_name}"
    series.resource.type = "global"
    
    if labels:
        for key, val in labels.items():
            series.metric.labels[key] = val
    
    point = monitoring_v3.Point()
    point.value.int64_value = value
    point.interval.end_time.seconds = int(time.time())
    series.points = [point]
    
    metrics_client.create_time_series(name=project_name, time_series=[series])
```

**Key Metrics**:
- `drafts_generated` - Total drafts created
- `drafts_approved` - Approved by humans
- `posts_created` - Successfully posted
- `posts_verified` - Verified as visible
- `posts_removed` - Detected as removed
- `llm_calls` - LLM API usage
- `reddit_api_calls` - Reddit API usage

---

## Alerts

**Critical Alerts** (page on-call):
```yaml
# alerts/high-error-rate.yaml
displayName: "High Error Rate"
conditions:
  - displayName: "Error rate > 5%"
    conditionThreshold:
      filter: 'metric.type="run.googleapis.com/request_count" AND metric.label.response_code_class="5xx"'
      comparison: COMPARISON_GT
      thresholdValue: 0.05
      duration: 300s
```

**Alerts**:
1. **High Error Rate** (>5%)
2. **Post Verification Failures** (>20%)
3. **Reddit API Errors** (>10/hour)
4. **Database Connection Failures**
5. **LLM Judge Rejections** (>50%)

**Warning Alerts** (email):
1. Draft generation slow (>2 min)
2. Approval rate low (<70%)
3. Rate limit approaching (>90%)

---

## Dashboards

**GCP Cloud Monitoring Dashboard**:
- System Health (CPU, memory, requests/sec)
- Business Metrics (drafts, approvals, posts)
- Error Rates
- Latency (p50, p95, p99)
- Reddit API Usage

**Custom Dashboard** (built in frontend):
- See [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md), Task 4.3

---

## Tracing

**Request Tracing**:
```python
# Middleware to inject trace ID
@app.middleware("http")
async def tracing_middleware(request, call_next):
    trace_id = str(uuid.uuid4())
    request.state.trace_id = trace_id
    
    structlog.contextvars.bind_contextvars(trace_id=trace_id)
    
    response = await call_next(request)
    response.headers["X-Trace-ID"] = trace_id
    
    return response
```

---

## On-Call Runbook

**High Error Rate**:
1. Check GCP logs for exceptions
2. Check Reddit API status
3. Rollback if recent deploy
4. Scale up if load spike

**Post Verification Failures**:
1. Check if Reddit is down
2. Check for API rate limits
3. Review recent posts for patterns
4. Check if accounts are banned

**Database Issues**:
1. Check Supabase status
2. Check connection pool
3. Review slow queries
4. Scale up if needed

---

## Key Queries

**Recent Errors**:
```
resource.type="cloud_run_revision"
severity="ERROR"
timestamp>="2024-01-01T00:00:00Z"
```

**Slow Requests**:
```
resource.type="cloud_run_revision"
httpRequest.latency>"2s"
```

**Company Activity**:
```
jsonPayload.company_id="xxx"
timestamp>="2024-01-01T00:00:00Z"
```

---

## Verification

- [ ] Structured logging in place
- [ ] Metrics recorded for key actions
- [ ] Alerts configured and tested
- [ ] Dashboard shows real-time data
- [ ] Can trace requests end-to-end

**Reference**: [24-LOGGING-DEBUGGING.md](./24-LOGGING-DEBUGGING.md), [M5-PRODUCTION.md](./M5-PRODUCTION.md)

