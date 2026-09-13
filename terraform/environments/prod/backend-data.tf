# Leitura por nome das 3 Lambdas do backend, que ficam no monorepo
# (backend/infra/terraform/environments/prod/{lambda.tf,
# lambda-account-trigger.tf, lambda-custom-message-trigger.tf}) — esta
# config nunca lê state do monorepo (direção única monorepo -> infra,
# ver CLAUDE.md). Data source em vez de string literal
# ("arn:aws:lambda:<region>:<account_id>:function:<nome>") porque o
# provider (>= 4.51) devolve arn/invoke_arn NÃO qualificados,
# idênticos aos que aws_lambda_function.<x>.arn/.invoke_arn devolviam —
# sem risco de update in-place em lambda_config (Cognito) ou
# integration_uri (API Gateway). Exige só lambda:GetFunction.
#
# Fallback, só se o plan pós-migração mostrar diff nesses atributos:
# string determinística
# "arn:aws:lambda:${var.aws_region}:${account_id}:function:<nome>" e
# "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/<arn>/invocations"
# (precisaria de data "aws_caller_identity" aqui).
data "aws_lambda_function" "api" {
  function_name = var.backend_api_function_name
}

data "aws_lambda_function" "account_trigger" {
  function_name = var.backend_account_trigger_function_name
}

data "aws_lambda_function" "custom_message_trigger" {
  function_name = var.backend_custom_message_trigger_function_name
}
