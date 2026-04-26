#!/bin/sh
# n8n initialization script
# Imports workflows and starts n8n with pre-configured credentials
# Credentials are injected via N8N_CREDENTIALS_OVERWRITE_DATA env var (no import needed)

set -e

echo "=== n8n Auto-Setup ==="

# Import workflows ONLY on first run.
# After first import, the live n8n DB is the source of truth.
# Use `iris n8n push` to update workflows from git → live n8n.
# Use `iris n8n pull` to save live n8n → git.
# DO NOT re-import on every restart — that overwrites UI changes.
WORKFLOW_DIR="/home/node/.n8n/workflows"
IMPORT_FLAG="/home/node/.n8n/.workflows-imported"

if [ ! -f "$IMPORT_FLAG" ]; then
    if [ -d "$WORKFLOW_DIR" ] && [ "$(ls -A $WORKFLOW_DIR/*.json 2>/dev/null)" ]; then
        echo "First run — importing seed workflows..."
        for f in "$WORKFLOW_DIR"/*.json; do
            echo "  Importing: $(basename $f)"
            n8n import:workflow --input="$f" 2>&1 || echo "  Warning: Failed to import $(basename $f)"
        done
        touch "$IMPORT_FLAG"
        echo "Workflow import complete. Future restarts will NOT re-import."
    else
        echo "No workflow files found in $WORKFLOW_DIR"
    fi
else
    echo "Workflows already imported (skipping). Use 'iris n8n push' to update."
fi

# Import credentials ONLY on first run (same logic).
CREDS_DIR="/home/node/.n8n/credentials"
CREDS_FLAG="/home/node/.n8n/.credentials-imported"

if [ ! -f "$CREDS_FLAG" ]; then
    if [ -d "$CREDS_DIR" ] && [ "$(ls -A $CREDS_DIR/*.json 2>/dev/null)" ]; then
        echo "First run — importing seed credentials..."
        for f in "$CREDS_DIR"/*.json; do
            echo "  Importing: $(basename $f)"
            n8n import:credentials --input="$f" 2>&1 || echo "  Warning: Failed to import $(basename $f)"
        done
        touch "$CREDS_FLAG"
        echo "Credential import complete."
    fi
else
    echo "Credentials already imported (skipping)."
fi

echo "Starting n8n..."

# Hand off to the default n8n entrypoint
exec n8n "$@"
