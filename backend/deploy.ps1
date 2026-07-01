# Deploy Battly backend + Zone admin with Docker Compose.
# Usage (from repo root):
#   .\backend\deploy.ps1
# Production API (goscrim):
#   $env:NEXT_PUBLIC_API_BASE_URL="https://api.goscrim.live/api"
#   $env:NEXT_PUBLIC_BACKEND_BASE_URL="https://api.goscrim.live"
#   .\backend\deploy.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building and starting Battly stack (API + Zone)..." -ForegroundColor Cyan

docker compose up -d --build app nginx zone worker reverb

Write-Host "Refreshing Laravel caches..." -ForegroundColor Cyan
docker compose exec -T app php artisan route:clear
docker compose exec -T app php artisan config:clear
docker compose exec -T app php artisan route:cache
docker compose exec -T app php artisan config:cache

Write-Host ""
Write-Host "Deploy complete." -ForegroundColor Green
Write-Host "  API:  http://localhost:8888/api"
Write-Host "  Zone: http://localhost:3000"
