#!/usr/bin/env bash
# FEAT-40 (backend), etapa 7 — move a plataforma de prod (DynamoDB,
# Cognito, Parameter Store, SES, API Gateway, domínio api + ACM/DNS) de
# backend/infra/terraform/environments/prod/ (monorepo) para
# terraform/environments/prod/ (infra-jrnexpenses). Lambdas, roles,
# policies, log groups e permissions ficam no monorepo (workload).
#
# ATENÇÃO: mesmo mecanismo da etapa 6 (hom), mas em cima de recursos de
# PRODUÇÃO reais — User Pool do Cognito com usuários e a tabela
# GastosApp com dados. Backups dos dois lados obrigatórios antes de
# rodar (ver plan.md §3 da FEAT-40).
#
# Roda em uma pasta scratch, contra dois arquivos de state locais
# (mono.tfstate / infra.tfstate), obtidos via `terraform state pull` de
# cada lado. `terraform state mv -state=... -state-out=...` não
# funciona com backend S3 configurado, por isso roda offline aqui.
#
# Endereço sem índice = move todas as instâncias (relevante para
# aws_route53_record.ses_dkim, count = 3, e
# aws_route53_record.api_acm_validation, for_each com 1 chave) — 24
# endereços, 26 instâncias no total. Lista revisada contra `terraform
# state list` de backend/infra/terraform/environments/prod/ (task 37 do
# tasks.md) antes de rodar.
#
# Diferenças de hom: aws_acm_certificate.api SEM
# aws_acm_certificate_validation (certificado já ISSUED, importado);
# nomes de domain_name/api_mapping/records sem sufixo "_hom"; 2 SSM de
# CORS (cors_production_origin_0/1) em vez de 1.
#
# Uso: bash wave-7-backend-prod.sh   (dentro da pasta scratch, com
# mono.tfstate e infra.tfstate já presentes)

set -euo pipefail

ADDRESSES=(
  "aws_dynamodb_table.gastos_app"
  "aws_cognito_user_pool.main"
  "aws_cognito_user_pool_client.spa"
  "aws_ssm_parameter.cognito_user_pool_id"
  "aws_ssm_parameter.cognito_client_id"
  "aws_ssm_parameter.cognito_region"
  "aws_ssm_parameter.cors_production_origin_0"
  "aws_ssm_parameter.cors_production_origin_1"
  "aws_ssm_parameter.ses_sender_email"
  "aws_ssm_parameter.logging_full_payload_enabled"
  "aws_ses_domain_identity.main"
  "aws_ses_domain_dkim.main"
  "aws_ses_domain_identity_verification.main"
  "aws_apigatewayv2_api.main"
  "aws_apigatewayv2_integration.lambda"
  "aws_apigatewayv2_route.default"
  "aws_apigatewayv2_stage.default"
  "aws_acm_certificate.api"
  "aws_apigatewayv2_domain_name.api"
  "aws_apigatewayv2_api_mapping.api"
  "aws_route53_record.api_acm_validation"
  "aws_route53_record.api_a"
  "aws_route53_record.ses_verification"
  "aws_route53_record.ses_dkim"
)

for addr in "${ADDRESSES[@]}"; do
  echo "==> movendo $addr"
  terraform state mv -state=mono.tfstate -state-out=infra.tfstate "$addr" "$addr"
done

echo "==> removendo data source órfão do monorepo (a infra relê por conta própria)"
terraform state rm -state=mono.tfstate data.aws_route53_zone.jrnexpenses

echo "==> concluído. Conferir com:"
echo "    terraform state list -state=infra.tfstate"
echo "    terraform state list -state=mono.tfstate"
