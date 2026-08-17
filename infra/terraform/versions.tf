terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Backend remoto recomendado para trabajo en equipo (requiere crear el bucket
  # y la tabla de DynamoDB de antemano). Descomentar y ajustar antes de "terraform init".
  #
  # backend "s3" {
  #   bucket         = "cuso-customers-tfstate"
  #   key            = "customers-app/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "cuso-customers-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# Lambda@Edge debe existir en us-east-1 sin importar en que region corra el resto
# del stack (requisito de CloudFront), por eso este segundo provider explicito.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
