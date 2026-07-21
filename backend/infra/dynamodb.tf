# Tabla única de bloqueos. DynamoDB borra solo los reportes caducados
# gracias al TTL sobre el atributo "expira_en" (epoch en segundos).
resource "aws_dynamodb_table" "bloqueos" {
  name         = "${local.prefix}-bloqueos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "estado"
    type = "S"
  }

  attribute {
    name = "creado_en"
    type = "S"
  }

  # Índice para listar rápido solo los bloqueos "activo", ordenados por fecha.
  global_secondary_index {
    name            = "activos-index"
    hash_key        = "estado"
    range_key       = "creado_en"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expira_en"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }
}

# Tabla de usuarios (login propio). PK `id` (uuid) + GSI `email-index` para el login.
resource "aws_dynamodb_table" "usuarios" {
  name         = "${local.prefix}-usuarios"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}
