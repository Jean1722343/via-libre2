# Laravel corre en Lambda como imagen de contenedor (Bref). La imagen se
# construye y sube a ECR ANTES de aplicar Terraform (ver scripts/desplegar.sh).

variable "imagen_tag" {
  description = "Tag de la imagen del contenedor Laravel en ECR."
  type        = string
  default     = "latest"
}

variable "app_key" {
  description = "APP_KEY de Laravel (base64:...). Genérala con: php artisan key:generate --show"
  type        = string
  sensitive   = true
}

resource "aws_lambda_function" "app" {
  function_name = "${local.prefix}-app"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.app.repository_url}:${var.imagen_tag}"
  timeout       = 28
  memory_size   = 1024

  environment {
    variables = {
      APP_ENV              = "production"
      APP_KEY              = var.app_key
      APP_DEBUG            = "false"
      LOG_CHANNEL          = "stderr"
      SESSION_DRIVER       = "array"
      CACHE_STORE          = "array"
      QUEUE_CONNECTION     = "sync"
      DB_CONNECTION        = "sqlite"
      DYNAMO_TABLA         = aws_dynamodb_table.bloqueos.name
      USUARIOS_TABLA       = aws_dynamodb_table.usuarios.name
      LOCATION_CALCULADORA = aws_location_route_calculator.rutas.calculator_name
      LOCATION_INDICE      = aws_location_place_index.lugares.index_name
      SNS_TOPICO           = aws_sns_topic.alertas.arn
      FOTOS_BUCKET         = aws_s3_bucket.fotos.bucket
      GOOGLE_CLIENT_ID     = var.google_client_id
      JWT_SECRET           = var.jwt_secret
      FACEBOOK_APP_ID      = var.facebook_app_id
      FACEBOOK_APP_SECRET  = var.facebook_app_secret
      TTL_HORAS            = tostring(var.ttl_horas)
      CORS_ORIGEN          = var.cors_origen
    }
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = 14
}
