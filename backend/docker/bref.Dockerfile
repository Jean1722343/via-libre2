# Imagen para DESPLEGAR Laravel en AWS Lambda con Bref (contenedor).
# Bref se añade solo aquí (no en el composer.json base) para no afectar el local.

FROM composer:2 AS build
WORKDIR /app
COPY . .
# require resuelve, instala (sin dev) y ejecuta package:discover -> genera
# bootstrap/cache/packages.php en build (el disco de Lambda es de solo lectura).
RUN composer require bref/bref bref/laravel-bridge \
      --no-interaction --update-no-dev -W --optimize-autoloader

FROM bref/php-83-fpm:2
COPY --from=build /app /var/task
# Bref usa este archivo como handler FPM (el front controller de Laravel).
CMD ["public/index.php"]
