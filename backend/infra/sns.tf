# Tópico de alertas: cada bloqueo nuevo publica aquí. Puedes suscribir
# correos o SMS desde la consola de AWS para recibir avisos en la demo.
resource "aws_sns_topic" "alertas" {
  name = "${local.prefix}-alertas"
}
