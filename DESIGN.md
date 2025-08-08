## VLM Evaluation Dashboard – Design Document

### Overview
- **Primary goal**: Manage vision-language model (VLM) experiment runs over PDF datasets with prompt versions sourced from Langfuse and pluggable evaluators (automated and human-ready).
- **Assumptions**: TypeScript/Next.js app, Postgres for metadata, in-process task runner (single-node) for orchestration, S3-compatible storage for artifacts, Langfuse for prompt registry and tracing.

### Goals and Scope
- **In-scope**
  - Dataset ingestion (PDFs) and parsing to images/text
  - Prompt selection/versioning via Langfuse
  - Model selection across multiple providers
  - Evaluator definition and execution (LLM-judge and heuristics)
  - Run orchestration, caching, resume, rate-limiting
  - Metrics, costs, traces, sample drill-down, run comparisons
- **Non-goals (initial)**
  - Full-fledged labeling/annotation suite
  - Multi-node distributed compute (optional later)
  - External labeling platforms (optional later)

### Personas & Core Use Cases
- **ML Engineer/Researcher**: Upload PDFs, configure parsing; pick prompt (Langfuse) + model; define evaluators; launch runs; monitor status/cost/metrics; inspect failures; compare to baselines; iterate.
- **PM/Stakeholder**: View high-level dashboards, trends, and comparisons.

### High-Level Architecture
- **Web App**: Next.js (App Router) for UI + API routes for control plane
- **Worker(s)**: In-process task runner(s) within the web process for ingestion, inference, evaluation (single-node)
- **Queue**: None initially; simple in-memory queueing (sequential execution)
- **Database**: Postgres via Prisma ORM
- **Object Storage**: S3-compatible (AWS S3 or MinIO) for PDFs, per-page images, artifacts
- **Langfuse**: Prompt registry + tracing (inference and judge)
- **Providers**: OpenAI (GPT-4o/mini), Anthropic (Claude 3.5), Google (Gemini 1.5), optional on-prem via vLLM/llama.cpp
- **Optional microservice**: Python FastAPI for robust PDF → image/text/OCR using PyMuPDF/pdf2image/Tesseract

### Data Model (entities)
- **Dataset**
  - id, name, description, tags
  - storage_location (S3 URI), created_by, created_at
  - parse_config: { page_to_image: { dpi, format }, text_extraction: { engine, ocr_fallback } }
  - version_hash
- **Document**
  - id, dataset_id, filename, file_hash, page_count, metadata (size, mimetype)
  - derived_assets_location (per-page image URIs), text_index_uri (optional)
- **Sample**
  - id, dataset_id, document_id, page_indices[], input_text?, expected_output?, metadata, tags[]
- **PromptBinding**
  - id, langfuse_prompt_slug, langfuse_version (pinned or latest), variables_schema, default_variables
- **ModelConfig**
  - id, provider, model_id, temperature, max_output_tokens, vision_input_mode (image_url/base64), system_prompt?
- **Evaluator**
  - id, type: 'llm_judge' | 'heuristic' | 'schema' | 'pairwise'
  - config JSON
    - llm_judge: { judge_model_config_id, judge_prompt_slug/version, rubric_items[], scoring_scale, thresholds }
    - heuristic: { matchers: [{ type: 'regex'|'contains'|'jsonpath', pattern, weight }], thresholds }
    - schema: { json_schema, validation_mode }
    - pairwise: { judge_model_config_id, judge_prompt_slug/version, preference_rubric }
- **Run**
  - id, name, dataset_version_hash, prompt_binding_id(+resolved version), model_config_id, evaluator_ids[], run_params (batch size, retry, cache policy), status, created_by
  - lineage: baseline_run_id?, notes
- **RunItem**
  - id, run_id, sample_id, input_payload (text + image refs), prompt_variables, model_output, error, status
  - timings, token_usage, provider_cost_estimate, langfuse_trace_ids
  - eval_results: [{ evaluator_id, scores, verdicts, explanations, judge_trace_id }]
- **AggregateMetrics**
  - run_id, metrics: { overall_score, pass@k, avg_cost, avg_latency, per-evaluator aggregates, tag-sliced aggregates }
- **ProviderCredential**
  - id, provider, alias, encrypted_key, limits (rpm, tpm, budget)
- **PriceBook** (optional)
  - provider, model_id, input_per_1k_tokens, output_per_1k_tokens, image/pricing params, effective_date

### Core Workflows
- **Dataset ingestion**
  - Upload PDFs → store in S3 → enqueue parsing → render per-page images and/or extract text; optional OCR fallback → create `Document` and `Sample` rows
- **Prompt binding (Langfuse)**
  - Select `prompt_slug`, pin version or track latest; map variables to sample fields; test
- **Model selection**
  - Choose provider/model; validate credentials/params; test call
- **Evaluator authoring**
  - Choose type; define rubric/heuristics/schema; preview on sample; persist
- **Run creation**
  - Wizard: dataset version + filters → prompt binding → model config → evaluators → run params (batch, concurrency, caching, limits)
  - Enqueue jobs; show live status, queue depth, rate-limits
- **Execution**
  - Build multimodal prompt (text + images) → call model with retries → log to Langfuse → run evaluators → store results → stream progress
  - Enforce RPM/TPM and budget; auto backoff on 429/5xx
- **Analysis**
  - Run detail: metrics, cost/latency charts, evaluator breakdowns, tag slices, error cohorts
  - Per-sample: PDF viewer, prompt vars, raw I/O, eval scores, judge reasoning, trace links
  - Compare runs: baseline vs candidate, deltas, pairwise win rates, filters

### Evaluation Types (initial library)
- **LLM Judge (rubric-based)**: 1–5 scoring with thresholds; judge prompt in Langfuse; separate judge model optional
- **Heuristic matchers**: regex/contains/jsonpath; weights; thresholds
- **Schema Validation**: JSON schema validation for structured outputs
- **Pairwise Preference**: A/B outputs judged per rubric
- Stretch: groundedness/hallucination checks, citation presence, layout fidelity, table extraction metrics

### Caching and Reproducibility
- Deterministic cache key: hash(model_id, prompt_version, variables, image/text content hashes, params)
- Cache policy: off | read-only | read-write; cross-run scoping configurable
- Version pinning: record resolved prompt version and dataset version hash on run creation

### Rate Limiting & Budgets
- Simple per-provider RPM/TPM controls with sleep-based pacing in a single process
- Run-level budget caps with hard stop
- Exponential backoff with jitter on throttling/errors

### Error Handling and Resume
- Configurable retry policy; circuit-breaking on repeated failures
- Resume runs from last successful item; per-item idempotency

### Observability
- Langfuse traces/spans for inference and judge; linkouts in UI
- Structured app logs; optional Prometheus/OpenTelemetry metrics
- Cost tracking per run, per sample, per provider

### Security & Compliance
- Secrets via env + optional KMS/Vault
- S3 presigned URLs for secure artifact access
- RBAC (admin, editor, viewer); audit log for changes

### UI Surface (pages)
- Home: recent runs, quick metrics, budget status
- Datasets: list, detail, upload, parse status, sample preview (PDF viewer)
- Prompts: browse Langfuse prompts, pin version, variable mapping
- Models: credentials, provider catalogs, test call
- Evaluators: library and builder; test on samples
- Runs: new run wizard; list; detail (charts, tables, filters); comparisons; per-sample drill-down
- Settings: providers, storage, rate limits, budgets, worker status

### API Outline (selected)
```http
POST   /api/datasets                 # create/upload init → presigned URLs
POST   /api/datasets/:id/parse       # start parsing
GET    /api/datasets/:id             # status, documents, samples
GET    /api/langfuse/prompts         # list slugs, versions
POST   /api/prompt-bindings          # create/update
GET    /api/models/providers         # available providers/models
POST   /api/evaluators               # create/update
POST   /api/runs                     # create
GET    /api/runs/:id                 # status, metrics
GET    /api/runs/:id/items           # paged items
GET    /api/runs/:id/compare/:baseId # baseline compare
POST   /api/test/inference           # dry-run inference on a sample
POST   /api/test/evaluator           # dry-run evaluator
```

### Storage Layout (S3)
- `datasets/{datasetId}/raw/{filename}.pdf`
- `datasets/{datasetId}/pages/{docId}/{pageIndex}.png`
- `datasets/{datasetId}/text/{docId}.jsonl`
- `runs/{runId}/items/{itemId}/artifacts/*`

### Technology Choices
- Frontend: Next.js (App Router), React, Tailwind/Chakra
- Backend: Next.js API routes, Prisma + Postgres, in-process task runner (no Redis)
- Langfuse: Node SDK for prompt fetch and tracing
- PDF processing: Node (pdf-lib/pdftoppm) for MVP; Python sidecar (FastAPI + PyMuPDF/pdf2image + Tesseract) for robustness
- Auth: NextAuth (GitHub/Google) or basic auth for MVP
- Deployment: Docker Compose (web, postgres, minio); optional cloud later

### Metrics & Visualizations
- Aggregates: accuracy/pass rate, average rubric score, invalid rate, cost/sample, latency
- Slices: by tag, document, page bucket, file size bucket
- Charts: line (over time), bar (per evaluator), scatter (latency vs score), stacked (cost by provider)
- Comparisons: delta tables, pairwise win rate, optional bootstrap CIs

### Initial Milestones
- M0 (Infra): DB schema, storage, auth, provider credentials, Langfuse integration
- M1 (Data): Dataset upload/parse, sample creation, viewer
- M2 (Run v1): Run wizard, inference pipeline, caching, basic metrics
- M3 (Evaluation): LLM judge + heuristics, per-sample drill-down, traces
- M4 (Compare): Baseline compare, slices, export
- M5 (Polish): Budgets, resume UX, RBAC, docs

### Risks & Mitigations
- PDF variability: OCR fallback; selectable parse modes
- Provider limits: adaptive rate limiting and backlog smoothing
- Judge bias/variance: multiple judges/ensembles; calibration
- Cost overruns: budgets, dry-runs, caching

### Open Questions
1. Do PDFs come with questions/answers or labels, or are runs purely prompt-driven without gold answers?
- I will start by creating some gold answers. So I need to add expected answer
2. Parsing mode: do you need text extraction, image pages, or both per run? Any OCR requirement for scans?
    Each run is the text extraction
3. Scale: typical dataset size (docs/pages/samples) and concurrent run volume?
 - We will start with small documents(2 pages)
4. Providers/models: which VLMs must be supported first (GPT-4o, Claude 3.5, Gemini 1.5, other)? Any on-prem/open-source VLM?
You can use openai specs to manage them as we are going to use openai or some platform to serve a model which use the openai specs.
5. Judge model: can we use a separate model as judge? Any cost ceiling for judges?
- Yes we can, not to start
6. Evaluation rubrics: predefined rubrics available, or ship a starter set (correctness, faithfulness, instruction adherence)?
    Correctness and instruction adherence
7. Prompt variables: any standard schema (e.g., { context, question }) used across prompts?
    you can create one 
8. Langfuse usage: should the dashboard also create/update prompts, or only read/pin existing ones?
    only read/pin as starter 
9. Caching: allow cross-run caching, or scope caches per run/project?
    Sure if it's help reduce the budget.
10. Budgets: need hard stop per run and/or per provider monthly caps?
per run
11. Access control: single-user initially, or multi-user with roles?
single-user
12. PDF size limits: any max file size/page counts to enforce?

Not for the moment but the application needs to be able to handle 2 pages pdf 
13. Export: required formats (CSV/Parquet/JSONL) and which fields (inputs, outputs, scores, costs)?
CSV and inputs outputs and name_of_each_evaluation with score, costs
14. Deployment target: local Docker only initially, or cloud (AWS/GCP) soon?
Target local development
15. Any compliance/security requirements (S3 vs. MinIO, KMS, VPN-only)?
Use MinIO


