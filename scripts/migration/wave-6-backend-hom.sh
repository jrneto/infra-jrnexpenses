#!/usr/bin/env bash
# FEAT-40 (backend), etapa 6 — move a plataforma de hom (DynamoDB,
# Cognito, Parameter Store, SES, API Gateway, domínio api-hom + ACM/DNS)
# de backend/infra/terraform/environments/hom/ (monorepo) para
# terraform/environments/hom/ (infra-jrnexpenses). Lambdas, roles,
# policies, log groups e permissions ficam no monorepo (workload).
#
# Roda em uma pasta scratch, contra dois arquivos de state locais
# (mono.tfstate / infra.tfstate), obtidos via `terraform state pull` de
# cada lado — mecanismo idêntico ao usado na FEAT-34 (ver
# backend/specs/FEAT-40-extracao-infra-repo-apartado/plan.md, §3).
# `terraform state mv -state=... -state-out=...` não funciona com
# backend S3 configurado, por isso roda offline aqui.
#
# Endereço sem índice = move todas as instâncias (relevante para
# aws_route53_record.ses_dkim, count = 3, e
# aws_route53_record.api_hom_acm_validation, for_each com 1 chave) — 24
# endereços, 26 instâncias no total. Lista revisada contra `terraform
# state list` de backend/infra/terraform/environments/hom/ (task 7 do
# tasks.md) antes de rodar.
#
# Além do mv, remove o data source órfão que fica sem uso no monorepo
# depois da migração (a infra o relê no próximo plan).
#
# Uso: bash wave-6-backend-hom.sh   (dentro da pasta scratch, com
# mono.tfstate e infra.tfstate já presentes)

set -euo pipefail

ADDRESSES=(
  "aws_dynamodb_table.gastos_app"
  "aws_cognito_user_pool.main"
  "aws_cognito_user_pool_client.spa"
  "aws_ssm_parameter.cognito_user_pool_id"
  "aws_ssm_parameter.cognito_client_id"
  "aws_ssm_parameter.cognito_region"
  "aws_ssm_parameter.cors_hom_origin_0"
  "aws_ssm_parameter.ses_sender_email"
  "aws_ssm_parameter.logging_full_payload_enabled"
  "aws_ses_domain_identity.main"
  "aws_ses_domain_dkim.main"
  "aws_ses_domain_identity_verification.main"
  "aws_apigatewayv2_api.main"
  "aws_apigatewayv2_integration.lambda"
  "aws_apigatewayv2_route.default"
  "aws_apigatewayv2_stage.default"
  "aws_acm_certificate.api_hom"
  "aws_acm_certificate_validation.api_hom"
  "aws_apigatewayv2_domain_name.api_hom"
  "aws_apigatewayv2_api_mapping.api_hom"
  "aws_route53_record.api_hom_acm_validation"
  "aws_route53_record.api_hom_a"
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
