#!/usr/bin/env bash
# FEAT-34 (frontend), etapa 4 — move a plataforma de prod
# (OAC + distribuição CloudFront + ACM + WAF) de
# frontend/infra/terraform/environments/prod/ (monorepo) para
# terraform/environments/prod/ (infra-jrnexpenses). Bucket, PAB, SSE e
# bucket policy ficam no monorepo (workload).
#
# Roda em uma pasta scratch, contra dois arquivos de state locais
# (mono.tfstate / infra.tfstate), obtidos via `terraform state pull` de
# cada lado — ver mecanismo em plan.md §3 da FEAT-34
# (frontend/specs/FEAT-34-extracao-infra-repo-apartado/plan.md).
#
# Lista revisada contra `terraform state list` de
# frontend/infra/terraform/environments/prod/ (task 34 do tasks.md)
# antes de rodar. ATENÇÃO: distribuição de produção — plan revisado
# linha a linha antes de cada state push (task 39), nenhum apply além
# do de outputs.
#
# Uso: bash wave-4-frontend-prod.sh   (dentro da pasta scratch, com
# mono.tfstate e infra.tfstate já presentes)

set -euo pipefail

ADDRESSES=(
  "aws_cloudfront_origin_access_control.frontend"
  "aws_cloudfront_distribution.main"
  "aws_acm_certificate.frontend"
  "aws_wafv2_web_acl.frontend"
)

for addr in "${ADDRESSES[@]}"; do
  echo "==> movendo $addr"
  terraform state mv -state=mono.tfstate -state-out=infra.tfstate "$addr" "$addr"
done

echo "==> concluído. Conferir com:"
echo "    terraform state list -state=infra.tfstate"
echo "    terraform state list -state=mono.tfstate"
