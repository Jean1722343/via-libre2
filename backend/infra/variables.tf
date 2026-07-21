variable "aws_region" {
  description = "Región de AWS donde se despliega todo el backend."
  type        = string
  default     = "us-east-1"
}

variable "proyecto" {
  description = "Nombre corto del proyecto, se usa como prefijo de los recursos."
  type        = string
  default     = "via-libre"
}

variable "entorno" {
  description = "Entorno lógico (dev, prod, demo...)."
  type        = string
  default     = "dev"
}

variable "cors_origen" {
  description = "Origen permitido para CORS (la URL del frontend). '*' está bien para la demo."
  type        = string
  default     = "*"
}

variable "ttl_horas" {
  description = "Horas de vigencia por defecto de un reporte antes de caducar si nadie lo confirma."
  type        = number
  default     = 2
}

variable "email_alertas" {
  description = "Correo para recibir avisos del presupuesto de AWS (80% y 100% de 10 USD). Opcional."
  type        = string
  default     = ""
}

variable "google_client_id" {
  description = "Google OAuth Client ID (Web) para verificar el login social. Vacío = Google dormido."
  type        = string
  default     = ""
}

variable "jwt_secret" {
  description = "Secreto para firmar los JWT de sesión (HS256). Genera uno largo y aleatorio."
  type        = string
  sensitive   = true
}

variable "facebook_app_id" {
  description = "Facebook App ID para verificar el login social. Vacío = Facebook dormido."
  type        = string
  default     = ""
}

variable "facebook_app_secret" {
  description = "Facebook App Secret. Vacío = Facebook dormido."
  type        = string
  sensitive   = true
  default     = ""
}
