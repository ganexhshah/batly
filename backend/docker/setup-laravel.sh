#!/bin/bash
###############################################################################
#  Battly Backend — Laravel 12 Initial Setup Script
#  Run this INSIDE the app container after first build
###############################################################################
set -e

echo "============================================"
echo "  Battly Backend — Laravel 12 Setup"
echo "============================================"

cd /var/www/html

# ── Step 1: Install Laravel 12 ───────────────────────────────────────────────
if [ ! -f "artisan" ]; then
    echo ""
    echo "▶ Installing Laravel 12..."
    composer create-project laravel/laravel tmp --prefer-dist --no-interaction
    # Move files from tmp to current directory
    cp -a tmp/. .
    rm -rf tmp
    echo "✓ Laravel 12 installed"
else
    echo "✓ Laravel already installed, skipping..."
fi

# ── Step 2: Copy environment file ────────────────────────────────────────────
if [ ! -f ".env" ]; then
    echo ""
    echo "▶ Setting up environment..."
    cp .env.example .env
    php artisan key:generate --force
    echo "✓ Environment configured"
else
    echo "✓ .env already exists"
fi

# ── Step 3: Install Sanctum (API auth) ──────────────────────────────────────
echo ""
echo "▶ Configuring Laravel Sanctum..."
php artisan install:api --no-interaction 2>/dev/null || true
echo "✓ Sanctum configured"

# ── Step 4: Install Socialite (Google OAuth) ─────────────────────────────────
echo ""
echo "▶ Installing Laravel Socialite..."
composer require laravel/socialite --no-interaction
echo "✓ Socialite installed"

# ── Step 5: Install Laravel Reverb (WebSockets) ─────────────────────────────
echo ""
echo "▶ Installing Laravel Reverb..."
composer require laravel/reverb --no-interaction
php artisan reverb:install --no-interaction 2>/dev/null || true
echo "✓ Reverb installed"

# ── Step 6: Install Scout + Meilisearch ──────────────────────────────────────
echo ""
echo "▶ Installing Laravel Scout + Meilisearch..."
composer require laravel/scout meilisearch/meilisearch-php --no-interaction
php artisan vendor:publish --provider="Laravel\Scout\ScoutServiceProvider" --no-interaction 2>/dev/null || true
echo "✓ Scout + Meilisearch installed"

# ── Step 7: Install Horizon (Queue Monitoring) ──────────────────────────────
echo ""
echo "▶ Installing Laravel Horizon..."
composer require laravel/horizon --no-interaction
php artisan horizon:install --no-interaction 2>/dev/null || true
echo "✓ Horizon installed"

# ── Step 8: Install Firebase (FCM Push Notifications) ───────────────────────
echo ""
echo "▶ Installing Firebase..."
composer require kreait/laravel-firebase --no-interaction
php artisan vendor:publish --provider="Kreait\Laravel\Firebase\ServiceProvider" --tag=config --no-interaction 2>/dev/null || true
echo "✓ Firebase installed"

# ── Step 9: Install Sentry (Error Tracking) ─────────────────────────────────
echo ""
echo "▶ Installing Sentry..."
composer require sentry/sentry-laravel --no-interaction
php artisan sentry:publish --dsn="" --no-interaction 2>/dev/null || true
echo "✓ Sentry installed"

# ── Step 10: Install AWS S3 Flysystem (for MinIO) ───────────────────────────
echo ""
echo "▶ Installing S3 Flysystem adapter (for MinIO)..."
composer require league/flysystem-aws-s3-v3 --no-interaction
echo "✓ S3 adapter installed"

# ── Step 11: Run Migrations ─────────────────────────────────────────────────
echo ""
echo "▶ Running migrations..."
php artisan migrate --force
echo "✓ Migrations complete"

# ── Step 12: Fix permissions ─────────────────────────────────────────────────
echo ""
echo "▶ Fixing permissions..."
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache
echo "✓ Permissions fixed"

echo ""
echo "============================================"
echo "  ✓ Battly Backend Setup Complete!"
echo "============================================"
echo ""
echo "Services:"
echo "  • App:          http://localhost"
echo "  • MinIO Console: http://localhost:9001"
echo "  • Meilisearch:  http://localhost:7700"
echo "  • WebSocket:    ws://localhost:8080"
echo ""
echo "Next steps:"
echo "  1. Set GOOGLE_CLIENT_ID & GOOGLE_CLIENT_SECRET in .env"
echo "  2. Place firebase-credentials.json in storage/app/"
echo "  3. Set SENTRY_LARAVEL_DSN in .env (optional)"
echo ""
