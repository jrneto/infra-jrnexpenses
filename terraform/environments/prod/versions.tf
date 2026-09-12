terraform {
  required_version = ">= 1.10" # necessário para locking nativo do backend S3 (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configuração parcial: 'bucket' e 'region' não ficam fixos aqui porque
  # o bucket de state é reaproveitado do backend (backend/infra/terraform/bootstrap/,
  # no monorepo) e pode variar por conta AWS. Forneça os valores
  # faltantes na hora do 'terraform init' com -backend-config (ver
  # README.md).
  #
  # Um state por ambiente: esta config passa a ser a plataforma inteira
  # de prod (frontend + backend, ver FEAT-40) — migrada do monorepo na
  # FEAT-34, etapa 4.
  backend "s3" {
    key          = "infra-jrnexpenses/prod/terraform.tfstate"
    use_lockfile = true # locking nativo do backend S3 — dispensa tabela DynamoDB extra
  }
}

provider "aws" {
  region = var.aws_region
}
