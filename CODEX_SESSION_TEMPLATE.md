# Codex Session Template

Use this as your default prompt when starting work in Codex for this repo.

## 1) Kickoff Prompt (copy/paste)

```text
You are working in /Users/josephruocco/nyc-street-history.

Project context:
- Backend: FastAPI + Postgres/PostGIS (Supabase)
- iOS: SwiftUI/CoreLocation
- Main endpoint: GET /v1/card?lat={lat}&lon={lon}&acc={accuracy}

Current state:
- street snapping, neighborhood lookup, fact lookup
- improved cross-street detection
- geohash TTL cache for /v1/card
- POI build/import scripts and category normalization

Rules for this task:
1. Make code changes directly in the repo.
2. Run relevant tests after edits.
3. Summarize exactly what changed with file paths.
4. If blocked, show the exact error and propose the smallest fix.

Task:
<PASTE YOUR TASK HERE>
```

## 2) Task Prompt Examples

### Add endpoint

```text
Implement /health/poi that returns total POI count and counts by category.
Add tests for the new endpoint behavior.
Run backend unit tests and report results.
```

### Data pipeline update

```text
Improve POI ingestion reliability.
- keep existing schema
- add validation logs for skipped records
- preserve current category mapping (park|landmark|transit|food)
Add or update tests.
```

### Debug mode

```text
Investigate this error and fix it end-to-end.
Show root cause, code fix, and verification commands.
Error:
<PASTE TRACEBACK>
```

## 3) Review Prompt (before commit)

```text
Review the current diff with a code-review mindset.
Prioritize findings: bugs, regressions, data correctness, missing tests.
List findings first with file references.
Then provide a short fix plan.
```

## 4) Commit Prompt

```text
Stage only files related to this task.
Create one clean commit with a descriptive message.
Show `git show --stat` summary.
```

## 5) Local Commands Reference

```bash
# Load env
cd /Users/josephruocco/nyc-street-history/backend
set -a; source ../.env; set +a

# Run API
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Run tests
python3 -m unittest discover -s tests -v

# Sample request
curl -s "http://127.0.0.1:8000/v1/card?lat=40.7183&lon=-73.9579&acc=25" | python3 -m json.tool
```
