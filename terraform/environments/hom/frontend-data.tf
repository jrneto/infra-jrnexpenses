# Leitura por nome do bucket S3 do frontend, que fica no monorepo
# (frontend/infra/terraform/environments/hom/s3.tf) — a distribuição
# precisa do domínio regional do bucket como origem, mas esta config
# nunca lê state do monorepo (direção única monorepo -> infra, ver
# CLAUDE.md). Data source em vez de string literal
# ("<bucket>.s3.<region>.amazonaws.com") porque o formato de
# bucket_regional_domain_name mudou entre versões do provider AWS para
# us-east-1 — o data source devolve exatamente o valor que o resource
# devolvia, sem risco de update in-place na origem da distribuição.
data "aws_s3_bucket" "frontend" {
  bucket = var.frontend_bucket_name
}
