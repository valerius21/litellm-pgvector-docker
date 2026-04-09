#!/bin/bash
set -e

MAX_RETRIES=30
RETRY_COUNT=0

echo "Running database migrations..."
until prisma db push --skip-generate --accept-data-loss 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Failed to run migrations after $MAX_RETRIES retries"
        exit 1
    fi
    echo "Database not ready, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "Starting application..."
exec uvicorn main:app --host 0.0.0.0 --port 8000