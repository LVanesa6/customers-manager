variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "backend_image" {
  description = "URI de la imagen del backend (por defecto usa el ECR repo creado por este modulo con tag 'latest')"
  type        = string
  default     = null
}

variable "keycloak_image" {
  description = "URI de la imagen de Keycloak (por defecto usa el ECR repo creado por este modulo con tag 'latest', con el realm y el tema ya incluidos)"
  type        = string
  default     = null
}

variable "db_endpoint" {
  type = string
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "backend_cpu" {
  type    = number
  default = 256
}

variable "backend_memory" {
  type    = number
  default = 512
}

variable "keycloak_cpu" {
  type    = number
  default = 512
}

variable "keycloak_memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "public_hostname" {
  description = <<-EOT
    Dominio publico real por el que los usuarios acceden a la app (el dominio de
    CloudFront, o tu propio dominio si usas uno). Se usa para que Keycloak arme sus
    URLs de login/redirect con ese dominio en vez del hostname interno del ALB.
    Se descubre solo despues del primer apply (CloudFront no existe todavia), por
    eso el flujo normal es: apply sin esta variable, tomar el output
    cloudfront_domain_name, y volver a aplicar pasandola.
  EOT
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = <<-EOT
    ARN de un certificado ACM (emitido para un dominio real, validado por DNS) para
    servir HTTPS de punta a punta CloudFront -> ALB. Si se deja null (por defecto),
    el ALB solo escucha HTTP en el puerto 80 -- suficiente para probar el stack pero
    no recomendado para produccion real con datos sensibles.
  EOT
  type        = string
  default     = null
}
