#!/bin/bash
set -e

# ── Ensure storage directories exist ────────────────────────────────
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/{cache,sessions,views}
mkdir -p /var/www/html/bootstrap/cache
mkdir -p /var/log/supervisor

# ── Fix permissions ─────────────────────────────────────────────────
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# ── Install Composer dependencies if vendor is missing ──────────────
if [ ! -d "/var/www/html/vendor" ] && [ -f "/var/www/html/composer.json" ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist --optimize-autoloader
fi

# ── Generate app key if not set ─────────────────────────────────────
if [ -f "/var/www/html/artisan" ]; then
    if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "" ]; then
        echo "Generating application key..."
        php artisan key:generate --force 2>/dev/null || true
    fi
fi

# ── Run only for the app container ──────────────────────────────────
if [ "$CONTAINER_ROLE" = "app" ]; then
    echo "Running migrations..."
    php artisan migrate --force 2>/dev/null || true

    echo "Caching configuration..."
    php artisan config:cache 2>/dev/null || true
    php artisan route:cache 2>/dev/null || true
    php artisan view:cache 2>/dev/null || true
fi

exec "$@"
