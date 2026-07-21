# Cognito Identity Pool con "invitados" (sin login) para que el navegador
# pueda pedir los tiles del mapa a Amazon Location de forma segura, sin
# exponer llaves permanentes en el frontend.

resource "aws_cognito_identity_pool" "invitados" {
  identity_pool_name               = "${local.prefix}-invitados"
  allow_unauthenticated_identities = true
}

data "aws_iam_policy_document" "cognito_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.invitados.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["unauthenticated"]
    }
  }
}

resource "aws_iam_role" "invitado" {
  name               = "${local.prefix}-rol-invitado"
  assume_role_policy = data.aws_iam_policy_document.cognito_trust.json
}

# El invitado solo puede LEER el mapa. Nada más.
data "aws_iam_policy_document" "mapa_lectura" {
  statement {
    actions = [
      "geo:GetMapStyleDescriptor",
      "geo:GetMapGlyphs",
      "geo:GetMapSprites",
      "geo:GetMapTile",
    ]
    resources = [aws_location_map.mapa.map_arn]
  }
}

resource "aws_iam_role_policy" "invitado_mapa" {
  name   = "acceso-mapa"
  role   = aws_iam_role.invitado.id
  policy = data.aws_iam_policy_document.mapa_lectura.json
}

resource "aws_cognito_identity_pool_roles_attachment" "invitados" {
  identity_pool_id = aws_cognito_identity_pool.invitados.id

  roles = {
    unauthenticated = aws_iam_role.invitado.arn
  }
}
