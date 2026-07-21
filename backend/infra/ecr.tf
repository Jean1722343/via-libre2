# Repositorio de imágenes: aquí se sube el contenedor de Laravel (Bref)
# que ejecuta la Lambda.
resource "aws_ecr_repository" "app" {
  name                 = "${local.prefix}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
