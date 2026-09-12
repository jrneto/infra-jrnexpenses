#!/usr/bin/env bash
# FEAT-34 (frontend), etapa 2 — move a hosted zone e os records de
# frontend/infra/terraform/dns/ (monorepo) para terraform/dns/ (infra-jrnexpenses).
#
# Roda em uma pasta scratch, contra dois arquivos de state locais
# (mono.tfstate / infra.tfstate), obtidos via `terraform state pull` de
# cada lado — ver mecanismo em plan.md §3 da FEAT-34
# (frontend/specs/FEAT-34-extracao-infra-repo-apartado/plan.md).
# `terraform state mv -state=... -state-out=...` não funciona com
# backend S3 configurado, por isso roda offline aqui.
#
# Endereço sem índice = move todas as instâncias (relevante para os dois
# for_each de validação ACM). Lista revisada contra `terraform state
# list` de frontend/infra/terraform/dns/ (task 8 do tasks.md) antes de
# rodar.
#
# Uso: bash wave-2-dns.sh   (dentro da pasta scratch, com mono.tfstate e
# infra.tfstate já presentes)

set -euo pipefail

ADDRESSES=(
  "aws_route53_zone.main"
  "aws_route53_record.apex_a"
  "aws_route53_record.apex_aaaa"
  "aws_route53_record.www_a"
  "aws_route53_record.www_aaaa"
  "aws_route53_record.acm_validation"
  "aws_route53_record.hom_a"
  "aws_route53_record.hom_aaaa"
  "aws_route53_record.acm_validation_hom"
)

for addr in "${ADDRESSES[@]}"; do
  echo "==> movendo $addr"
  terraform state mv -state=mono.tfstate -state-out=infra.tfstate "$addr" "$addr"
done

echo "==> concluído. Conferir com:"
echo "    terraform state list -state=infra.tfstate"
echo "    terraform state list -state=mono.tfstate"
