variable "name" {
  description = "Prefijo para nombrar los recursos de RDS"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDRs con acceso permitido a MySQL (tipicamente las subnets privadas donde corren las tasks de ECS)"
  type        = list(string)
}

variable "engine_version" {
  type    = string
  default = "8.0"
}

variable "instance_class" {
  description = "Clase de instancia RDS (db.t4g.micro es elegible para free tier)"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "customers_db"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
