output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "keycloak_ecr_repository_url" {
  value = aws_ecr_repository.keycloak.repository_url
}

output "tasks_security_group_id" {
  value = aws_security_group.tasks.id
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "backend_service_arn" {
  value = aws_ecs_service.backend.id
}

output "keycloak_service_arn" {
  value = aws_ecs_service.keycloak.id
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.backend.arn
}

output "keycloak_ecr_repository_arn" {
  value = aws_ecr_repository.keycloak.arn
}
