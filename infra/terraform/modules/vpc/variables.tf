variable "name" {
  description = "Prefijo para nombrar los recursos de red"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar (2 recomendado para alta disponibilidad basica)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las subnets publicas (una por AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs para las subnets privadas (una por AZ)"
  type        = list(string)
}
