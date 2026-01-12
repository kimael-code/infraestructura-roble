# ============================================
# STAGE 1: Builder (Build assets y dependencias)
# ============================================
FROM php:8.4-fpm-alpine AS builder

ARG TZ=UTC
ARG LOCALE=en_US.UTF-8

LABEL maintainer="Maikel Carballo"

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Instalar herramientas de build (git, node, npm)
RUN apk add -U --no-cache \
    git \
    nodejs \
    npm \
    tzdata \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && apk del tzdata

# Instalar extensiones PHP necesarias para build
RUN curl -sSLf \
    -o /usr/local/bin/install-php-extensions \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions && \
    chmod +x /usr/local/bin/install-php-extensions

RUN install-php-extensions pgsql pdo_pgsql gd intl zip pcntl sockets

# Copiar composer desde imagen oficial
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# PASO 1: Copiar archivos de dependencias
COPY ./src/roble/composer.json ./src/roble/composer.lock ./

# PASO 2: Instalar dependencias PHP (sin scripts, se ejecutarán después)
RUN composer install --prefer-dist --no-dev --optimize-autoloader --no-interaction --no-scripts

# PASO 3: Copiar package.json y package-lock.json
COPY ./src/roble/package*.json ./

# PASO 4: Instalar dependencias Node
RUN npm ci

# PASO 5: Copiar TODO el código fuente (necesario para Wayfinder y build)
COPY ./src/roble/ ./

# PASO 5.5: Regenerar autoloader ahora que todo el código está presente
RUN composer dump-autoload --optimize --classmap-authoritative

# PASO 6: Generar APP_KEY para que Laravel pueda bootear (.env ya existe por install.sh)
RUN php artisan key:generate --force -n --ansi

# PASO 7: Ahora sí, build de assets (Wayfinder puede ejecutar artisan correctamente)
RUN npm run build:ssr

# PASO 8: Optimización de node_modules para producción
# Eliminar node_modules completo y reinstalar SOLO dependencias de producción
# Esto reduce el tamaño de ~700-900 MB a ~300-400 MB
RUN rm -rf node_modules && \
    npm ci --omit=dev --ignore-scripts && \
    npm cache clean --force

# PASO 9: Limpiar cache de composer para reducir tamaño adicional
RUN composer clear-cache

# ============================================
# STAGE 2: Production (Solo runtime)
# ============================================
FROM php:8.4-fpm-alpine AS production

ARG TZ=UTC
ARG LOCALE=en_US.UTF-8

LABEL maintainer="Maikel Carballo"

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Dependencias de runtime (Node.js es necesario para SSR worker)
RUN apk add -U --no-cache \
    supervisor \
    nodejs \
    tzdata \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && apk del tzdata

# Instalar extensiones PHP para producción
RUN curl -sSLf \
    -o /usr/local/bin/install-php-extensions \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions && \
    chmod +x /usr/local/bin/install-php-extensions

RUN install-php-extensions pgsql pdo_pgsql gd intl zip pcntl sockets

# Limpiar installer para reducir tamaño
RUN rm -f /usr/local/bin/install-php-extensions

ENV TZ=${TZ}
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}

WORKDIR /var/www/html

# Copiar código y assets compilados desde builder
COPY --from=builder /var/www/html /var/www/html

# Copiar configuraciones
COPY ./supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./php/php.ini "$PHP_INI_DIR/conf.d/php.ini"

# Setup Laravel para producción
RUN chown -R www-data:www-data /var/www/html && \
    php artisan key:generate --force -n --ansi && \
    php artisan storage:link && \
    php artisan optimize && \
    rm -f .env

# Limpiar caches
RUN rm -rf /tmp/* /var/cache/apk/*

USER www-data

EXPOSE 9000 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
