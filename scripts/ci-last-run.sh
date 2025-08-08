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

# Fetch latest run ID for the workflow (optionally filter by branch) using gh run list
if [[ -n "$WORKFLOW_FILE" ]]; then
  # Map file to workflow name
  WORKFLOW_NAME=$(gh api "repos/$REPO_SLUG/actions/workflows" --jq \
    "([.workflows[] | select(.path==\"$WORKFLOW_FILE\")] | first // empty) | .name")
fi

RUN_ID=$(gh run list --workflow "$WORKFLOW_NAME" ${BRANCH:+--branch "$BRANCH"} --limit 1 --json databaseId --jq '.[0].databaseId')

if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
  echo "Error: No runs found for workflow '$WORKFLOW_NAME' ${BRANCH:+on branch '$BRANCH'}." >&2
  exit 2
fi

if $OUTPUT_JSON; then
  gh run view "$RUN_ID" --json databaseId,workflowName,displayTitle,headBranch,status,conclusion,url,createdAt
else
  gh run view "$RUN_ID" --json workflowName,displayTitle,headBranch,status,conclusion,url,createdAt --template \
    '{{.workflowName}} | {{.displayTitle}}\nBranch: {{.headBranch}}\nStatus: {{.status}} | Conclusion: {{.conclusion}}\nURL: {{.url}}\nCreated: {{.createdAt}}\n'
fi

if $WATCH_RUN; then
  gh run watch "$RUN_ID"
fi

if $SHOW_LOGS; then
  gh run view "$RUN_ID" --log
fi


