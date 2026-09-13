variable "aws_region" {
  description = "Região AWS. CloudFront/ACM (usado em CloudFront)/WAF (scope CLOUDFRONT) exigem us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "hom_domain_name" {
  description = "Domínio do frontend de homologação. Sem variante www (ambiente interno, sem necessidade identificada)."
  type        = string
  default     = "hom.jrnexpenses.com"
}

variable "frontend_bucket_name" {
  description = "Nome do bucket S3 que serve o build estático do frontend de homologação via CloudFront — gerenciado no monorepo, lido aqui por data source (ver frontend-data.tf)."
  type        = string
  default     = "gastosapp-frontend-hom"
}

# Backend (FEAT-40, etapa 6)

variable "table_name" {
  description = "Nome da tabela DynamoDB de homologação do backend (backend-dynamodb.tf)."
  type        = string
  default     = "GastosApp-Hom"
}

variable "frontend_origins" {
  description = "Origens de CORS liberadas no API Gateway do backend, homologação (backend-api-gateway.tf)."
  type        = list(string)
  default     = ["https://hom.jrnexpenses.com"]
}

variable "backend_api_function_name" {
  description = "Nome da função Lambda da API do backend, homologação — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "gastos-app-api-hom"
}

variable "backend_account_trigger_function_name" {
  description = "Nome da função Lambda do trigger PostConfirmation do Cognito, homologação — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "jrnexpenses-account-trigger-hom"
}

variable "backend_custom_message_trigger_function_name" {
  description = "Nome da função Lambda do trigger CustomMessage do Cognito, homologação — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "jrnexpenses-custom-message-trigger-hom"
}
