# Rol de ejecución que usan todas las funciones Lambda.

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.prefix}-rol-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permisos mínimos: DynamoDB (tabla + índice), Location (ruta + geocode) y SNS.
data "aws_iam_policy_document" "lambda_permisos" {
  statement {
    sid = "Dynamo"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.bloqueos.arn,
      "${aws_dynamodb_table.bloqueos.arn}/index/*",
      aws_dynamodb_table.usuarios.arn,
      "${aws_dynamodb_table.usuarios.arn}/index/*",
    ]
  }

  statement {
    sid     = "Location"
    actions = ["geo:CalculateRoute", "geo:SearchPlaceIndexForText"]
    resources = [
      aws_location_route_calculator.rutas.calculator_arn,
      aws_location_place_index.lugares.index_arn,
    ]
  }

  statement {
    sid       = "Sns"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alertas.arn]
  }

  statement {
    sid       = "S3Fotos"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.fotos.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_permisos" {
  name   = "permisos-app"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permisos.json
}
