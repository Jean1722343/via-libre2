#!/usr/bin/env bash
set -e
cd /var/www

if [ ! -f vendor/autoload.php ]; then
  echo "==> Instalando dependencias (composer). La primera vez tarda un poco..."
  composer update --no-interaction --prefer-dist
fi

# Escribimos la config en .env: 'php artisan serve' NO reenvía las variables de
# docker-compose al worker HTTP, pero Laravel SÍ lee el archivo .env al arrancar.
if [ ! -f .env ]; then
  cat > .env <<'EOF'
APP_NAME="Via Libre Oaxaca"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000
LOG_CHANNEL=stderr
SESSION_DRIVER=array
CACHE_STORE=array
QUEUE_CONNECTION=sync
DB_CONNECTION=sqlite
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=local
AWS_SECRET_ACCESS_KEY=local
DYNAMO_ENDPOINT=http://dynamodb-local:8000
DYNAMO_TABLA=via-libre-bloqueos
USUARIOS_TABLA=via-libre-usuarios
JWT_SECRET=via-libre-jwt-local-dev
TTL_HORAS=2
CORS_ORIGEN=*
EOF
fi

if ! grep -q "^APP_KEY=base64" .env; then
  php artisan key:generate --force
fi

echo "==> Esperando a DynamoDB Local..."
until curl -s http://dynamodb-local:8000 >/dev/null 2>&1; do sleep 1; done

php artisan dynamo:crear-tabla || true
php artisan dynamo:sembrar || true
php artisan usuarios:crear-admin || true

echo "==> Laravel listo en http://localhost:8000/api"
exec php artisan serve --host 0.0.0.0 --port 8000
