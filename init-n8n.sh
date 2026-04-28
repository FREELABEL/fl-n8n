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

# Check if workflows already exist in the DATABASE (not a flag file — volumes can reset).
# If postgres has workflows, the DB is the source of truth. Never overwrite.
EXISTING_COUNT=0
if command -v psql >/dev/null 2>&1; then
    EXISTING_COUNT=$(PGPASSWORD="${DB_POSTGRESDB_PASSWORD:-n8n_password}" psql -h "${DB_POSTGRESDB_HOST:-postgres-n8n}" -U "${DB_POSTGRESDB_USER:-n8n}" -d "${DB_POSTGRESDB_DATABASE:-n8n}" -t -A -c "SELECT COUNT(*) FROM workflow_entity;" 2>/dev/null || echo "0")
fi

if [ "$EXISTING_COUNT" -gt "0" ] 2>/dev/null; then
    echo "Database has $EXISTING_COUNT workflow(s) — skipping import (DB is source of truth)."
    echo "Use 'iris n8n push' to update workflows from git."
else
    if [ -d "$WORKFLOW_DIR" ] && [ "$(ls -A $WORKFLOW_DIR/*.json 2>/dev/null)" ]; then
        echo "Empty database — importing seed workflows..."
        for f in "$WORKFLOW_DIR"/*.json; do
            echo "  Importing: $(basename $f)"
            n8n import:workflow --input="$f" 2>&1 || echo "  Warning: Failed to import $(basename $f)"
        done
        echo "Workflow import complete."
    else
        echo "No workflow files found in $WORKFLOW_DIR"
    fi
fi

# Import credentials ONLY on first run (same logic).
CREDS_DIR="/home/node/.n8n/credentials"

# Same DB check for credentials
CREDS_COUNT=0
if command -v psql >/dev/null 2>&1; then
    CREDS_COUNT=$(PGPASSWORD="${DB_POSTGRESDB_PASSWORD:-n8n_password}" psql -h "${DB_POSTGRESDB_HOST:-postgres-n8n}" -U "${DB_POSTGRESDB_USER:-n8n}" -d "${DB_POSTGRESDB_DATABASE:-n8n}" -t -A -c "SELECT COUNT(*) FROM credentials_entity;" 2>/dev/null || echo "0")
fi

if [ "$CREDS_COUNT" -gt "0" ] 2>/dev/null; then
    echo "Database has $CREDS_COUNT credential(s) — skipping import."
else
    if [ -d "$CREDS_DIR" ] && [ "$(ls -A $CREDS_DIR/*.json 2>/dev/null)" ]; then
        echo "Empty database — importing seed credentials..."
        for f in "$CREDS_DIR"/*.json; do
            echo "  Importing: $(basename $f)"
            n8n import:credentials --input="$f" 2>&1 || echo "  Warning: Failed to import $(basename $f)"
        done
        echo "Credential import complete."
    fi
fi

echo "Starting n8n..."

# Hand off to the default n8n entrypoint
exec n8n "$@"
