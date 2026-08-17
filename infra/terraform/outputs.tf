output "alb_dns_name" {
  description = "DNS del Application Load Balancer (backend en /api y Keycloak en /auth)"
  value       = module.ecs.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "Dominio publico de la aplicacion (frontend Angular servido via CloudFront)"
  value       = module.frontend.cloudfront_domain_name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR donde publicar la imagen del backend"
  value       = module.ecs.ecr_repository_url
}

output "keycloak_ecr_repository_url" {
  description = "URL del repositorio ECR donde publicar la imagen personalizada de Keycloak"
  value       = module.ecs.keycloak_ecr_repository_url
}

output "frontend_bucket_name" {
  description = "Bucket S3 donde se debe subir el build de Angular (dist/frontend/browser)"
  value       = module.frontend.bucket_name
}

output "db_endpoint" {
  description = "Endpoint de la instancia RDS MySQL"
  value       = module.rds.db_endpoint
}

output "github_actions_role_arn" {
  description = "ARN del rol IAM que GitHub Actions asume via OIDC para desplegar (null si no se definio var.github_repository). Se usa en el workflow con aws-actions/configure-aws-credentials, y como secreto AWS_DEPLOY_ROLE_ARN en el repo de GitHub."
  value       = var.github_repository != null ? aws_iam_role.github_actions[0].arn : null
}
