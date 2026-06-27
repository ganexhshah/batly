#======================================================================
# Laravel 12 / PHP 8.4-FPM — Battly Backend
#======================================================================
# syntax=docker/dockerfile:1
FROM php:8.4-fpm-alpine AS app

LABEL maintainer="Battly Backend"

# ── System dependencies ──────────────────────────────────────────────
# linux-headers — required for sockets extension compilation
# (provides linux/sock_diag.h needed by ext/sockets)
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
    bash \
    curl \
    git \
    icu-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    libxml2-dev \
    linux-headers \
    oniguruma-dev \
    postgresql-dev \
    supervisor \
    $PHPIZE_DEPS

# ── PHP extensions ───────────────────────────────────────────────────
# xml   — built into PHP 8.4 core; no install needed
# opcache — pre-compiled shared ext in base image; just enable it
RUN --mount=type=cache,target=/tmp \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_pgsql \
        pgsql \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        sockets \
        mbstring \
    && docker-php-ext-enable opcache \
    && pecl install redis \
    && docker-php-ext-enable redis

# ── Composer ─────────────────────────────────────────────────────────
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ── Working directory ────────────────────────────────────────────────
WORKDIR /var/www/html

# ── PHP config ───────────────────────────────────────────────────────
COPY docker/php/local.ini /usr/local/etc/php/conf.d/local.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# ── Entrypoint ───────────────────────────────────────────────────────
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Ensure storage dirs ─────────────────────────────────────────────
RUN mkdir -p /var/www/html/storage/logs \
    && mkdir -p /var/www/html/storage/framework/{cache,sessions,views} \
    && mkdir -p /var/www/html/bootstrap/cache \
    && mkdir -p /var/log/supervisor

EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
