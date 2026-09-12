output "cloudfront_domain_name" {
  description = "Domínio *.cloudfront.net da distribuição — usado pela config dns/ via terraform_remote_state para os records alias."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID fixo da CloudFront — usado pela config dns/ nos records alias."
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "acm_domain_validation_options" {
  description = "Dados de validação DNS do certificado ACM — usados pela config dns/ para os CNAMEs de validação."
  value       = aws_acm_certificate.frontend.domain_validation_options
}

output "cloudfront_distribution_arn" {
  description = "ARN da distribuição de prod — lido pela config environments/prod/ do monorepo (aws_s3_bucket_policy.frontend, AWS:SourceArn) via terraform_remote_state."
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição de prod — informativo, bate com o DISTRIBUTION_ID cadastrado no GitHub Environment prod e com terraform/cicd/frontend/variables.tf."
  value       = aws_cloudfront_distribution.main.id
}
