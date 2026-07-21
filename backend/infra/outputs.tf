# Estos valores los necesita el frontend (cópialos a frontend/.env).
# Ejecuta "terraform output" después del apply para verlos.

output "api_url" {
  description = "URL base de la API (incluye /api) -> NUXT_PUBLIC_API_URL"
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/api"
}

output "ecr_repo_url" {
  description = "URL del repositorio ECR donde se sube la imagen de Laravel."
  value       = aws_ecr_repository.app.repository_url
}

output "region" {
  description = "Región -> NUXT_PUBLIC_AWS_REGION"
  value       = var.aws_region
}

output "mapa_nombre" {
  description = "Nombre del mapa -> NUXT_PUBLIC_MAP_NAME"
  value       = aws_location_map.mapa.map_name
}

output "identity_pool_id" {
  description = "Identity Pool -> NUXT_PUBLIC_IDENTITY_POOL_ID"
  value       = aws_cognito_identity_pool.invitados.id
}

output "topico_alertas_arn" {
  description = "ARN del tópico SNS (para suscribir correo/SMS en la consola)."
  value       = aws_sns_topic.alertas.arn
}

output "tabla_bloqueos" {
  description = "Nombre de la tabla DynamoDB."
  value       = aws_dynamodb_table.bloqueos.name
}

output "tabla_usuarios" {
  description = "Nombre de la tabla DynamoDB de usuarios (para crear el admin)."
  value       = aws_dynamodb_table.usuarios.name
}

output "fotos_bucket" {
  description = "Bucket S3 donde se guardan las fotos de los bloqueos."
  value       = aws_s3_bucket.fotos.bucket
}

output "web_url" {
  description = "URL pública del frontend (CloudFront, HTTPS)."
  value       = "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "web_bucket" {
  description = "Bucket S3 donde se suben los archivos del frontend."
  value       = aws_s3_bucket.web.bucket
}

output "cloudfront_id" {
  description = "ID de la distribución CloudFront (para invalidar caché al actualizar)."
  value       = aws_cloudfront_distribution.web.id
}
