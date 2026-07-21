# Bucket para las fotos de los bloqueos. El frontend sube directo con una URL
# firmada (ver FotoController) y las imágenes se sirven públicas para el mapa.

data "aws_caller_identity" "actual" {}

resource "aws_s3_bucket" "fotos" {
  # El nombre de bucket es global; el id de cuenta lo hace único.
  bucket = "${local.prefix}-fotos-${data.aws_caller_identity.actual.account_id}"
}

# Las fotos son públicas de lectura (no hay datos sensibles), pero bloqueamos ACLs.
resource "aws_s3_bucket_public_access_block" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "fotos_publica" {
  bucket     = aws_s3_bucket.fotos.id
  depends_on = [aws_s3_bucket_public_access_block.fotos]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LecturaPublica"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.fotos.arn}/*"
    }]
  })
}

# CORS: el navegador sube la foto con PUT desde el frontend.
resource "aws_s3_bucket_cors_configuration" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_origins = [var.cors_origen]
    max_age_seconds = 3600
  }
}

# Las fotos caducan a los 30 días (ahorro de costo; el bloqueo ya no existe).
resource "aws_s3_bucket_lifecycle_configuration" "fotos" {
  bucket = aws_s3_bucket.fotos.id

  rule {
    id     = "caducar-fotos"
    status = "Enabled"

    filter {
      prefix = "bloqueos/"
    }

    expiration {
      days = 30
    }
  }
}
