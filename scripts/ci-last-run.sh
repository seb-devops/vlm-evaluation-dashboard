#!/usr/bin/env bash
set -euo pipefail

# ci-last-run.sh
# Retrieve the latest GitHub Actions workflow run for this repo.
# Requires: GitHub CLI (gh)

WORKFLOW_NAME="Infra Check"  # default workflow name
BRANCH=""
OUTPUT_JSON=false
SHOW_LOGS=false
WATCH_RUN=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--workflow "Infra Check" | --file .github/workflows/infra-check.yml] [--branch BRANCH] [--json] [--logs] [--watch]

Options:
  --workflow NAME   Workflow name (default: "Infra Check")
  --file PATH       Workflow file path (e.g., .github/workflows/infra-check.yml)
  --branch BRANCH   Filter by branch (default: latest across branches)
  --json            Print raw JSON of the last run
  --logs            Fetch and print logs for the last run
  --watch           Stream run status until completion
  -h, --help        Show this help
USAGE
}

WORKFLOW_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow)
      WORKFLOW_NAME="$2"; shift 2 ;;
    --file)
      WORKFLOW_FILE="$2"; shift 2 ;;
    --branch)
      BRANCH="$2"; shift 2 ;;
    --json)
      OUTPUT_JSON=true; shift ;;
    --logs)
      SHOW_LOGS=true; shift ;;
    --watch)
      WATCH_RUN=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI 'gh' is not installed." >&2
  exit 1
fi

# Determine owner/repo slug via gh
REPO_SLUG=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
if [[ -z "$REPO_SLUG" ]]; then
  echo "Error: Unable to determine GitHub repo. Run within a git repo with a GitHub remote configured." >&2
  exit 1
fi

# Resolve workflow ID by name or file path
resolve_workflow_id() {
  local wid=""
  if [[ -n "$WORKFLOW_FILE" ]]; then
    wid=$(gh api "repos/$REPO_SLUG/actions/workflows" --jq \
      "([.workflows[] | select(.path==\"$WORKFLOW_FILE\")] | first // empty) | .id" || true)
  else
    wid=$(gh api "repos/$REPO_SLUG/actions/workflows" --jq \
      "([.workflows[] | select(.name==\"$WORKFLOW_NAME\")] | first // empty) | .id" || true)
  fi
  if [[ -z "$wid" || "$wid" == "null" ]]; then
    echo "Error: Workflow not found (name='$WORKFLOW_NAME' file='$WORKFLOW_FILE')." >&2
    exit 1
  fi
  echo "$wid"
}

WORKFLOW_ID=$(resolve_workflow_id)

# Fetch latest run for the workflow (optionally filter by branch)
RUN_JSON=""
if [[ -n "$BRANCH" ]]; then
  RUN_JSON=$(gh api "repos/$REPO_SLUG/actions/workflows/$WORKFLOW_ID/runs?branch=$BRANCH&per_page=1" --jq \
    ".workflow_runs[0]")
else
  RUN_JSON=$(gh api "repos/$REPO_SLUG/actions/workflows/$WORKFLOW_ID/runs?per_page=1" --jq \
    ".workflow_runs[0]")
fi

if [[ -z "$RUN_JSON" || "$RUN_JSON" == "null" ]]; then
  echo "Error: No runs found for workflow." >&2
  exit 2
fi

RUN_ID=$(echo "$RUN_JSON" | gh api --input - --jq .id)

if $OUTPUT_JSON; then
  echo "$RUN_JSON"
else
  NAME=$(echo "$RUN_JSON" | gh api --input - --jq .name)
  STATUS=$(echo "$RUN_JSON" | gh api --input - --jq .status)
  CONCLUSION=$(echo "$RUN_JSON" | gh api --input - --jq .conclusion)
  EVENT=$(echo "$RUN_JSON" | gh api --input - --jq .event)
  HEAD_BRANCH=$(echo "$RUN_JSON" | gh api --input - --jq .head_branch)
  URL=$(echo "$RUN_JSON" | gh api --input - --jq .html_url)
  CREATED=$(echo "$RUN_JSON" | gh api --input - --jq .created_at)
  echo "Workflow: ${WORKFLOW_NAME}${WORKFLOW_FILE:+ ($WORKFLOW_FILE)}"
  echo "Repo: $REPO_SLUG"
  echo "Run ID: $RUN_ID"
  echo "Name: $NAME"
  echo "Branch: $HEAD_BRANCH"
  echo "Event: $EVENT"
  echo "Status: $STATUS"
  echo "Conclusion: ${CONCLUSION:-n/a}"
  echo "URL: $URL"
  echo "Created: $CREATED"
fi

if $WATCH_RUN; then
  gh run watch "$RUN_ID"
fi

if $SHOW_LOGS; then
  gh run view "$RUN_ID" --log
fi


