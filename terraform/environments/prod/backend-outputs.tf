# Outputs lidos pelo monorepo (backend/infra/terraform/environments/prod/)
# via terraform_remote_state — direção única infra -> monorepo nunca o
# inverso (ver CLAUDE.md). Consumidores: políticas IAM e variáveis de
# ambiente das 3 Lambdas de workload (FEAT-40, plan.md §2.1/§2.2).

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB de produção provisionada — usado na env DynamoDb__TableName da Lambda do trigger de conta, no monorepo (a API de prod não declara essa variável)."
  value       = aws_dynamodb_table.gastos_app.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB de produção provisionada — usado nas policies lambda_exec/account_trigger_lambda_exec, no monorepo."
  value       = aws_dynamodb_table.gastos_app.arn
}

output "cognito_user_pool_arn" {
  description = "ARN do User Pool do Cognito de produção — usado na policy lambda_exec (CognitoAccess) e no source_arn das aws_lambda_permission.cognito_invoke_*, no monorepo."
  value       = aws_cognito_user_pool.main.arn
}

output "ses_domain_identity_arn" {
  description = "ARN da identidade de domínio SES de produção verificada — usado nas policies lambda_exec/account_trigger_lambda_exec (SesSendEmail), no monorepo."
  value       = aws_ses_domain_identity.main.arn
}

output "api_gateway_execution_arn" {
  description = "Execution ARN do HTTP API de produção — usado no source_arn de aws_lambda_permission.apigateway, no monorepo."
  value       = aws_apigatewayv2_api.main.execution_arn
}

output "api_gateway_url" {
  description = "URL pública base do HTTP API de produção (informativo)."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_custom_domain_url" {
  description = "URL pública da API de produção através do domínio customizado (informativo)."
  value       = "https://${aws_apigatewayv2_domain_name.api.domain_name}"
}

output "ses_sender_email" {
  description = "Remetente usado pelo Cognito e pelas Lambdas de produção para envio via SES (informativo)."
  value       = aws_cognito_user_pool.main.email_configuration[0].from_email_address
}
