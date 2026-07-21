#!/usr/bin/env bash
# Despliega el backend en AWS: ECR + imagen de Laravel (Bref) + Terraform.
# Requisitos: AWS CLI configurado (aws configure), Docker corriendo, Terraform.
set -euo pipefail
cd "$(dirname "$0")/.."

REGION=${AWS_REGION:-us-east-1}

# APP_KEY: usa la que pases en TF_VAR_app_key o genera una nueva.
: "${TF_VAR_app_key:=base64:$(openssl rand -base64 32)}"
export TF_VAR_app_key

cd infra

echo "==> 1/5 Terraform init + crear ECR..."
terraform init -input=false
terraform apply -target=aws_ecr_repository.app -auto-approve

ECR=$(terraform output -raw ecr_repo_url)
REGISTRY=${ECR%%/*}

echo "==> 2/5 Login a ECR ($REGISTRY)..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> 3/5 Construir y subir imagen de Laravel (Bref)..."
cd ..
docker build -f docker/bref.Dockerfile -t "$ECR:latest" .
docker push "$ECR:latest"

echo "==> 4/5 Aplicar el resto de la infraestructura..."
cd infra
terraform apply -auto-approve

echo "==> 5/5 Listo. Copia estos valores a frontend/.env:"
terraform output
