# Imagen para DESARROLLO LOCAL (php artisan serve). El despliegue en AWS
# usa Bref (ver docker/bref.Dockerfile), no esta imagen.
FROM php:8.3-cli

RUN apt-get update && apt-get install -y \
        git unzip curl libzip-dev libonig-dev \
    && docker-php-ext-install zip bcmath mbstring pcntl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
