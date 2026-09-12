#!/usr/bin/env bash
# FEAT-34 (frontend), etapa 3 — move a plataforma de hom
# (OAC + distribuição CloudFront + ACM + WAF) de
# frontend/infra/terraform/environments/hom/ (monorepo) para
# terraform/environments/hom/ (infra-jrnexpenses). Bucket, PAB, SSE e
# bucket policy ficam no monorepo (workload).
#
# Roda em uma pasta scratch, contra dois arquivos de state locais
# (mono.tfstate / infra.tfstate), obtidos via `terraform state pull` de
# cada lado — ver mecanismo em plan.md §3 da FEAT-34
# (frontend/specs/FEAT-34-extracao-infra-repo-apartado/plan.md).
#
# Lista revisada contra `terraform state list` de
# frontend/infra/terraform/environments/hom/ (task 19 do tasks.md)
# antes de rodar.
#
# Uso: bash wave-3-frontend-hom.sh   (dentro da pasta scratch, com
# mono.tfstate e infra.tfstate já presentes)

set -euo pipefail

ADDRESSES=(
  "aws_cloudfront_origin_access_control.frontend"
  "aws_cloudfront_distribution.main"
  "aws_acm_certificate.hom"
  "aws_wafv2_web_acl.hom"
)

for addr in "${ADDRESSES[@]}"; do
  echo "==> movendo $addr"
  terraform state mv -state=mono.tfstate -state-out=infra.tfstate "$addr" "$addr"
done

echo "==> concluído. Conferir com:"
echo "    terraform state list -state=infra.tfstate"
echo "    terraform state list -state=mono.tfstate"
