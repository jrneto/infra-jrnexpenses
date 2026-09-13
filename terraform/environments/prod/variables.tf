variable "aws_region" {
  description = "Região AWS. CloudFront/ACM (usado em CloudFront)/WAF (scope CLOUDFRONT) exigem us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domínio principal do frontend."
  type        = string
  default     = "jrnexpenses.com"
}

variable "frontend_bucket_name" {
  description = "Nome do bucket S3 que serve o build estático do frontend via CloudFront — gerenciado no monorepo, lido aqui por data source (ver frontend-data.tf)."
  type        = string
  default     = "gastosapp-frontend-prod"
}

# Backend (FEAT-40, etapa 7)

variable "table_name" {
  description = "Nome da tabela DynamoDB de produção do backend (backend-dynamodb.tf)."
  type        = string
  default     = "GastosApp"
}

variable "frontend_origins" {
  description = "Origens de CORS liberadas no API Gateway do backend, produção (backend-api-gateway.tf)."
  type        = list(string)
  default     = ["https://jrnexpenses.com", "https://www.jrnexpenses.com"]
}

variable "backend_api_function_name" {
  description = "Nome da função Lambda da API do backend, produção — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "gastos-app-api"
}

variable "backend_account_trigger_function_name" {
  description = "Nome da função Lambda do trigger PostConfirmation do Cognito, produção — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "jrnexpenses-account-trigger"
}

variable "backend_custom_message_trigger_function_name" {
  description = "Nome da função Lambda do trigger CustomMessage do Cognito, produção — gerenciada no monorepo, lida aqui por data source (ver backend-data.tf)."
  type        = string
  default     = "jrnexpenses-custom-message-trigger"
}
