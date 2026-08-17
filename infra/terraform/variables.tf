variable "aws_region" {
  description = "Region de AWS donde se despliega todo el stack"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo usado para nombrar todos los recursos"
  type        = string
  default     = "cuso-customers"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_username" {
  description = "Usuario administrador de la base de datos MySQL"
  type        = string
  sensitive   = true
  default     = "customers_user"
}

variable "db_password" {
  description = "Password del usuario de la base de datos MySQL (usar una variable de entorno TF_VAR_db_password en lugar de un valor por defecto)"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Password del usuario admin de Keycloak (usar TF_VAR_keycloak_admin_password)"
  type        = string
  sensitive   = true
}

variable "backend_image" {
  description = "URI completa de la imagen del backend en ECR. Si se deja nula, se usa el repo ECR creado por este modulo con tag 'latest'"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = <<-EOT
    ARN de un certificado ACM (dominio real, validado por DNS) para servir HTTPS de
    punta a punta CloudFront -> ALB. Dejar en null (default) si no tienes un dominio
    propio -- el stack funciona igual, solo que el tramo CloudFront->ALB queda en HTTP.
  EOT
  type        = string
  default     = null
}

variable "public_hostname" {
  description = <<-EOT
    Dominio publico real de la app (el de CloudFront, o el tuyo si usas uno). Se
    descubre solo tras el primer apply -- por eso el flujo es: apply sin esta
    variable, ver el output cloudfront_domain_name, y volver a aplicar pasandola
    (por ejemplo TF_VAR_public_hostname=xxxxx.cloudfront.net).
  EOT
  type        = string
  default     = null
}

variable "github_repository" {
  description = <<-EOT
    Repo de GitHub autorizado a asumir (via OIDC) el rol de despliegue, formato
    "usuario/repo" (ej. "LVanesaF/customers-manager"). Mientras quede en null
    (default) no se crea ningun recurso de GitHub Actions/OIDC.
  EOT
  type        = string
  default     = null
}
