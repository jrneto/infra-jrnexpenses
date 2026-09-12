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
  # no monorepo) e pode variar por conta AWS. Forneça os valores faltantes
  # na hora do 'terraform init' com -backend-config (ver README.md).
  #
  # Camada persistente: nunca destruída (migrada do monorepo na FEAT-34,
  # etapa 2 — frontend/specs/FEAT-34-extracao-infra-repo-apartado/).
  backend "s3" {
    key          = "infra-jrnexpenses/dns/terraform.tfstate"
    use_lockfile = true # locking nativo do backend S3 — dispensa tabela DynamoDB extra
  }
}

provider "aws" {
  region = var.aws_region
}
