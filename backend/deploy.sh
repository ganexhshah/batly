#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

export NEXT_PUBLIC_API_BASE_URL="${NEXT_PUBLIC_API_BASE_URL:-http://localhost:8888/api}"
export NEXT_PUBLIC_BACKEND_BASE_URL="${NEXT_PUBLIC_BACKEND_BASE_URL:-http://localhost:8888}"

echo "Building and starting Battly stack (API + Zone)..."
docker compose up -d --build app nginx zone worker reverb

echo "Refreshing Laravel caches..."
docker compose exec -T app php artisan route:clear
docker compose exec -T app php artisan config:clear
docker compose exec -T app php artisan route:cache
docker compose exec -T app php artisan config:cache

echo ""
echo "Deploy complete."
echo "  API:  http://localhost:8888/api"
echo "  Zone: http://localhost:3000"
