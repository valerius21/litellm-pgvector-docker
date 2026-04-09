#!/bin/bash
set -e

MAX_RETRIES=30
RETRY_COUNT=0

echo "Waiting for database to be ready..."
until pg_isready -h pgvector -p 5432 -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-vectors}" 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Database not available after $MAX_RETRIES retries"
        echo "DATABASE_URL: postgresql://${POSTGRES_USER:-app}:***@pgvector:5432/${POSTGRES_DB:-vectors}"
        exit 1
    fi
    echo "Database not ready, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done
echo "Database is ready!"

echo "Ensuring pgvector extension exists..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h pgvector -p 5432 -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-vectors}" -c 'CREATE EXTENSION IF NOT EXISTS vector;'

# Alter vector column dimensions if EMBEDDING__DIMENSIONS is set and differs from current schema
if [ -n "${EMBEDDING__DIMENSIONS:-}" ]; then
    echo "Altering embedding dimensions to ${EMBEDDING__DIMENSIONS}..."
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h pgvector -p 5432 -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-vectors}" -c "ALTER TABLE embeddings ALTER COLUMN embedding TYPE vector(${EMBEDDING__DIMENSIONS}) USING embedding::vector(${EMBEDDING__DIMENSIONS});" || echo "Note: Could not alter embeddings column (may not exist yet or data incompatible)"
fi

echo "Running database migrations..."
RETRY_COUNT=0
until prisma db push --skip-generate --accept-data-loss; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Failed to run migrations after $MAX_RETRIES retries"
        exit 1
    fi
    echo "Migration failed, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "Starting application..."
exec uvicorn main:app --host 0.0.0.0 --port 8000