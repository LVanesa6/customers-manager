variable "name" {
  type = string
}

variable "alb_dns_name" {
  description = "DNS del ALB que expone el backend (/api/*) y Keycloak (/auth/*)"
  type        = string
}

variable "alb_https_enabled" {
  description = "Si el ALB tiene un listener HTTPS (certificado ACM), CloudFront le habla por HTTPS en vez de HTTP"
  type        = bool
  default     = false
}

variable "public_hostname" {
  description = <<-EOT
    Dominio publico real de la app (el de CloudFront, o el tuyo). Se usa en una
    CloudFront Function que inyecta X-Forwarded-Host/X-Forwarded-Proto hacia el
    ALB, porque CloudFront reescribe el header Host al dominio del origin (el ALB)
    y Keycloak necesita saber el dominio publico real para armar sus URLs de login.
    Null (default) en el primer apply, antes de conocer el dominio de CloudFront.
  EOT
  type        = string
  default     = null
}
