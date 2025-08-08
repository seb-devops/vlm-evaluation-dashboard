#!/usr/bin/env bash
set -euo pipefail

echo "Creating GitHub issues for VLM Evaluation Dashboard..."

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI 'gh' is not installed. Install from https://cli.github.com and re-run." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' and re-run." >&2
  exit 1
fi

# Determine repo context: prefer current git repo; otherwise require GH_REPO env var (owner/repo)
REPO_ARG=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Inside a git repo; gh will infer repo from origin
  :
else
  if [[ -z "${GH_REPO:-}" ]]; then
    echo "Error: Not in a git repo and GH_REPO is not set. Set GH_REPO=owner/repo and re-run." >&2
    exit 1
  fi
  REPO_ARG=(--repo "$GH_REPO")
fi

# Validate repo access
if ! gh repo view "${REPO_ARG[@]}" >/dev/null 2>&1; then
  echo "Error: Unable to access the GitHub repo. Ensure the repo exists and you have rights. If using GH_REPO, verify the slug (owner/repo)." >&2
  exit 1
fi

issue_exists() {
  local title="$1"
  # Checks if an issue with the exact title already exists (any state)
  if gh issue list "${REPO_ARG[@]}" --search "$title in:title" --state all --limit 100 | grep -Fq "$title"; then
    return 0
  else
    return 1
  fi
}

create_issue() {
  local title="$1"
  local body="$2"
  local milestone="$3" # informational only; not using GitHub milestone API here

  local full_title="$milestone: $title"

  if issue_exists "$full_title"; then
    echo "Skip (exists): $full_title"
    return 0
  fi

  gh issue create "${REPO_ARG[@]}" \
    --title "$full_title" \
    --body "$body" \
    >/dev/null

  echo "Created: $full_title"
}

########################################
# M0 – Infrastructure and Foundations  #
########################################

read -r -d '' BODY << 'EOF'
Description:
Add docker-compose services for Postgres, Redis, and MinIO. Provide example env and helpers.

Deliverables:
- docker-compose.yml, .env.example, Makefile targets

Acceptance Criteria:
- `docker compose up` brings services healthy
- MinIO, Postgres, Redis reachable from app

Dependencies: None
EOF
create_issue "Bootstrap Docker Compose (Postgres, Redis, MinIO)" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Initialize Prisma ORM, DB connection, and first migration setup.

Deliverables:
- prisma/schema.prisma, migration files, scripts

Acceptance Criteria:
- `prisma migrate dev` succeeds on local DB

Dependencies: Docker Compose
EOF
create_issue "Prisma setup and migration baseline" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Implement core Prisma models for text-only flows with gold answers: Dataset, Document, Sample (expected_answer), PromptBinding, ModelConfig, Evaluator, Run, RunItem, ProviderCredential, AggregateMetrics, PriceBook (optional).

Deliverables:
- Prisma models + seed script

Acceptance Criteria:
- Models align with DESIGN.md and requirements
- Seed creates minimal working state

Dependencies: Prisma baseline
EOF
create_issue "Core schema v1 (text-only, gold answers)" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Centralized environment configuration with validation for DB, Redis, MinIO, Langfuse, OpenAI-compatible endpoint.

Deliverables:
- config.ts with env parsing (zod or similar)

Acceptance Criteria:
- Missing critical envs produce clear startup errors

Dependencies: None
EOF
create_issue "Server config and configuration module" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Bootstrap BullMQ with Redis, queue connection helpers, and a health endpoint.

Deliverables:
- Worker bootstrap, queue helper, health route

Acceptance Criteria:
- Can enqueue/dequeue a sample job locally end-to-end

Dependencies: Docker Compose
EOF
create_issue "Redis + BullMQ scaffolding" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Implement S3/MinIO client abstraction with presigned URL support and bucket initialization.

Deliverables:
- storageClient.ts, bucket init

Acceptance Criteria:
- Put/get object and generate presigned URL against MinIO

Dependencies: Docker Compose
EOF
create_issue "S3/MinIO client abstraction" "$BODY" "M0"

read -r -d '' BODY << 'EOF'
Description:
Initialize Langfuse SDK, provide wrapper for traces/spans with safe no-op when not configured.

Deliverables:
- observability/langfuse.ts

Acceptance Criteria:
- Can create a test trace or no-op cleanly

Dependencies: Config
EOF
create_issue "Langfuse SDK integration scaffolding" "$BODY" "M0"

#############################
# M1 – Dataset and Parsing   #
#############################

read -r -d '' BODY << 'EOF'
Description:
API to create dataset metadata and generate presigned upload URLs for PDFs.

Deliverables:
- POST /api/datasets with validation and presigned URLs

Acceptance Criteria:
- Can upload via presigned URL; dataset row created

Dependencies: Storage client, schema
EOF
create_issue "Dataset upload API with presigned URLs" "$BODY" "M1"

read -r -d '' BODY << 'EOF'
Description:
Worker job to extract text per page from uploaded PDFs and create Document + Sample rows.

Deliverables:
- parseDataset job using pdf-parse or pdfjs-dist

Acceptance Criteria:
- For a 2-page PDF, creates Document and two Samples with text payload

Dependencies: Worker, storage client
EOF
create_issue "Parsing job: PDF text extraction (per-page)" "$BODY" "M1"

read -r -d '' BODY << 'EOF'
Description:
API to trigger parsing for a dataset and update status.

Deliverables:
- POST /api/datasets/:id/parse enqueues job and reports status

Acceptance Criteria:
- Dataset transitions parsing → ready; job enqueued

Dependencies: Parsing job
EOF
create_issue "Trigger parsing API" "$BODY" "M1"

read -r -d '' BODY << 'EOF'
Description:
UI pages to create dataset, upload PDF, trigger parsing, and view status.

Deliverables:
- Next.js pages/forms, dataset list/detail

Acceptance Criteria:
- Create dataset → upload → parse → see ready state

Dependencies: Dataset APIs
EOF
create_issue "Datasets UI: list/create/parse status" "$BODY" "M1"

read -r -d '' BODY << 'EOF'
Description:
Component to preview per-page extracted text for small PDFs.

Deliverables:
- Sample preview component integrated in dataset detail

Acceptance Criteria:
- For a 2-page PDF, both pages’ text visible

Dependencies: Dataset APIs
EOF
create_issue "Sample preview UI (text-only, per-page)" "$BODY" "M1"

########################################
# M2 – Prompts, Models, Run Creation   #
########################################

read -r -d '' BODY << 'EOF'
Description:
Backend wrappers to list Langfuse prompts/versions and store PromptBinding (read/pin only).

Deliverables:
- GET /api/langfuse/prompts, POST /api/prompt-bindings

Acceptance Criteria:
- Can read/pin prompt versions; no writes to Langfuse

Dependencies: Langfuse SDK
EOF
create_issue "Langfuse prompt browse/read/pin API" "$BODY" "M2"

read -r -d '' BODY << 'EOF'
Description:
Define `{ context, question, instructions }` variable schema and mapping to samples.

Deliverables:
- Schema validation and mapping UI in binding form

Acceptance Criteria:
- Can map sample fields to variables; validated on save

Dependencies: Prompt binding
EOF
create_issue "Prompt variables schema (MVP)" "$BODY" "M2"

read -r -d '' BODY << 'EOF'
Description:
Implement client for OpenAI-compatible endpoints (configurable base URL and key) with a test route.

Deliverables:
- modelClient.ts, POST /api/test/inference

Acceptance Criteria:
- Test inference succeeds against configured OpenAI-spec endpoint

Dependencies: Config
EOF
create_issue "OpenAI-spec compatible model client" "$BODY" "M2"

read -r -d '' BODY << 'EOF'
Description:
Create/update ModelConfig entities (model_id, temperature, max_tokens) via API and UI.

Deliverables:
- CRUD endpoints and forms

Acceptance Criteria:
- Can save/update configs with validation

Dependencies: None
EOF
create_issue "ModelConfig CRUD (UI + API)" "$BODY" "M2"

read -r -d '' BODY << 'EOF'
Description:
Wizard to choose dataset, prompt binding, model config, evaluators (placeholder), run params (batch, concurrency), budget cap.

Deliverables:
- UI wizard and POST /api/runs

Acceptance Criteria:
- Run can be created and enqueued

Dependencies: Dataset, prompt, model CRUD
EOF
create_issue "Run creation wizard (MVP)" "$BODY" "M2"

############################################
# M2.5 – Execution Pipeline and Caching    #
############################################

read -r -d '' BODY << 'EOF'
Description:
Worker pipeline that builds text prompts for each sample, calls model, and persists RunItem.

Deliverables:
- Processor with status updates

Acceptance Criteria:
- Processes small run; items complete/failed with errors captured

Dependencies: Model client, queue
EOF
create_issue "Execution pipeline job (inference)" "$BODY" "M2.5"

read -r -d '' BODY << 'EOF'
Description:
Add Langfuse trace/span creation for each inference and store trace id in RunItem.

Deliverables:
- Trace wrapper usage in pipeline

Acceptance Criteria:
- Each RunItem has associated trace id

Dependencies: Pipeline
EOF
create_issue "Langfuse tracing for inference" "$BODY" "M2.5"

read -r -d '' BODY << 'EOF'
Description:
Deterministic caching using a stable key (model_id, prompt_version, variables, text hash, params) with read-write policy.

Deliverables:
- Cache module and integration into pipeline

Acceptance Criteria:
- Re-running same input hits cache; hits recorded

Dependencies: Pipeline
EOF
create_issue "Deterministic caching (read-write)" "$BODY" "M2.5"

read -r -d '' BODY << 'EOF'
Description:
Track estimated cost per item and stop run when per-run budget cap is exceeded.

Deliverables:
- Budget manager and status transitions

Acceptance Criteria:
- Run stops when cap hit; surfaced in UI

Dependencies: Pipeline, pricebook/static pricing
EOF
create_issue "Per-run budget cap" "$BODY" "M2.5"

###############################
# M3 – Evaluation and Metrics #
###############################

read -r -d '' BODY << 'EOF'
Description:
Compare model output to expected_answer with normalization (lowercase, trim, punctuation, whitespace).

Deliverables:
- Evaluator module + unit tests

Acceptance Criteria:
- Normalized exact matches score 1, else 0; stored per item

Dependencies: Run items
EOF
create_issue "Evaluator: Correctness (gold answer, exact/normalized)" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
String similarity fallback (Jaro-Winkler or Levenshtein) to produce partial scores.

Deliverables:
- Configurable threshold; score in [0,1]

Acceptance Criteria:
- Scores reflect similarity; threshold configurable

Dependencies: Correctness (normalized)
EOF
create_issue "Evaluator: Correctness (string similarity fallback)" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Heuristic checks for instruction adherence (required keywords/format markers) with weights and thresholds.

Deliverables:
- Configurable matchers and scoring

Acceptance Criteria:
- Fails when required elements missing; score stored with notes

Dependencies: Evaluator framework
EOF
create_issue "Evaluator: Instruction adherence (heuristics)" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Standard evaluator interface, registry, and orchestration with persistence in RunItem.eval_results.

Deliverables:
- Interface, registry, execution in pipeline

Acceptance Criteria:
- Multiple evaluators can run per item and store results

Dependencies: Pipeline
EOF
create_issue "Evaluator framework and storage" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Compute per-run aggregates (accuracy, avg score, latency, cost) and persist in AggregateMetrics.

Deliverables:
- Aggregator job and API exposure

Acceptance Criteria:
- Aggregates available after run completion

Dependencies: Evaluations complete
EOF
create_issue "Aggregates and metrics computation" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Run detail page with basic charts and items table (status, outputs, scores, cost).

Deliverables:
- Page and components

Acceptance Criteria:
- Shows aggregates; table filter by status/evaluator

Dependencies: Aggregates API
EOF
create_issue "Run detail UI (metrics + items table)" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Per-sample drilldown to view input text, prompt variables, model output, evaluation scores, and Langfuse trace link.

Deliverables:
- Drawer/page component

Acceptance Criteria:
- All fields visible; trace link works

Dependencies: Traces in pipeline
EOF
create_issue "Per-sample drilldown UI" "$BODY" "M3"

read -r -d '' BODY << 'EOF'
Description:
Export run data to CSV including inputs, outputs, each evaluation score, and cost fields.

Deliverables:
- GET /api/runs/:id/export.csv

Acceptance Criteria:
- CSV contains required fields (inputs, outputs, per-eval scores, costs)

Dependencies: Items populated
EOF
create_issue "CSV export (inputs, outputs, evaluations, costs)" "$BODY" "M3"

################################
# M4 – Comparison and Slices   #
################################

read -r -d '' BODY << 'EOF'
Description:
Compare a run vs a baseline run with delta metrics and per-item diffs by sample id.

Deliverables:
- GET /api/runs/:id/compare/:baselineId

Acceptance Criteria:
- Returns deltas and win/loss counts for correctness

Dependencies: Aggregates
EOF
create_issue "Baseline selection and run comparison API" "$BODY" "M4"

read -r -d '' BODY << 'EOF'
Description:
UI to display comparison deltas and changed items with filters and links to drilldown.

Deliverables:
- Compare page and components

Acceptance Criteria:
- Clear up/down deltas; links to both items’ drilldown

Dependencies: Compare API
EOF
create_issue "Compare UI (metrics deltas + table)" "$BODY" "M4"

############################
# M5 – Polish & Reliability #
############################

read -r -d '' BODY << 'EOF'
Description:
Local single-user guard (basic session), config-gated for easy local development.

Deliverables:
- Auth middleware/routes

Acceptance Criteria:
- UI gated; can disable via config

Dependencies: None
EOF
create_issue "Simple single-user auth" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Standardize retries with exponential backoff and classify error categories.

Deliverables:
- Retry helper applied to provider calls

Acceptance Criteria:
- 429/5xx retried with jitter; permanent errors surfaced

Dependencies: Pipeline
EOF
create_issue "Retry/backoff and error categories" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Resume incomplete runs and ensure idempotent item processing.

Deliverables:
- Resume logic and idempotency keys

Acceptance Criteria:
- Re-running a run skips completed items; safe post-crash resume

Dependencies: Pipeline
EOF
create_issue "Resume runs and idempotency" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
RPM/TPM rate limiting with adaptive concurrency control.

Deliverables:
- Rate limiter and concurrency controller

Acceptance Criteria:
- Holds under configured RPM; avoids sustained 429s

Dependencies: Pipeline
EOF
create_issue "Rate limiting and adaptive concurrency (RPM/TPM)" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Update README with setup, envs, and an end-to-end local run guide.

Deliverables:
- Setup docs and workflow guide

Acceptance Criteria:
- New dev can run E2E on a 2-page PDF

Dependencies: M1–M3
EOF
create_issue "Documentation (README updates + local run guide)" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Configure MinIO buckets and minimal policies for local development; document setup.

Deliverables:
- Scripts or docs for bucket setup

Acceptance Criteria:
- Buckets exist with expected names; presigned URLs function

Dependencies: S3 client
EOF
create_issue "MinIO IAM and bucket policies (local)" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Static price book and cost estimator to compute per-item and aggregate costs.

Deliverables:
- Price config and estimator module

Acceptance Criteria:
- Costs computed and aggregated per run

Dependencies: Pipeline
EOF
create_issue "Price book (static) and cost estimation" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
ESLint/Prettier and test scaffolding (Jest/Vitest) with CI-friendly scripts.

Deliverables:
- Config files and sample tests

Acceptance Criteria:
- Lint and tests pass locally

Dependencies: None
EOF
create_issue "Lints, types, and test scaffolding" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Shared UI components for error views and empty/loading states.

Deliverables:
- Components and usage on key pages

Acceptance Criteria:
- Clear empty and error states across main pages

Dependencies: UI pages
EOF
create_issue "Error views and empty states" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
Feature flag to switch between cross-run caching and per-run cache scope.

Deliverables:
- Config flag and enforcement in cache lookups

Acceptance Criteria:
- Toggling flag changes cache hit behavior

Dependencies: Caching
EOF
create_issue "Feature flag: cross-run cache scope" "$BODY" "M5"

read -r -d '' BODY << 'EOF'
Description:
UI to trigger CSV export and download via signed link; optional retention policy.

Deliverables:
- Button, async job if needed, signed download

Acceptance Criteria:
- User can export CSV; link expiry works

Dependencies: CSV export API
EOF
create_issue "Export UX and file retention" "$BODY" "M5"

echo "All issue creation attempts finished."


