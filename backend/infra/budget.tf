# Presupuesto de AWS: tope de 10 USD al mes para no llevarte sorpresas.
# Si defines "email_alertas", AWS te avisa al 80% y al 100% del gasto.
# (El presupuesto AVISA, no corta el servicio: AWS no apaga recursos solo.)

resource "aws_budgets_budget" "mensual" {
  name         = "${local.prefix}-presupuesto"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.email_alertas == "" ? [] : [80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.email_alertas]
    }
  }
}
