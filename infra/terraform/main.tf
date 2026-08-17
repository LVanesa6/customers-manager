module "vpc" {
  source = "./modules/vpc"

  name                 = var.project_name
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

module "rds" {
  source = "./modules/rds"

  name                = var.project_name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  allowed_cidr_blocks = module.vpc.private_subnet_cidrs
  db_username         = var.db_username
  db_password         = var.db_password
}

module "ecs" {
  source = "./modules/ecs"

  name                    = var.project_name
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  backend_image           = var.backend_image
  db_endpoint             = module.rds.db_endpoint
  db_port                 = module.rds.db_port
  db_name                 = "customers_db"
  db_username             = var.db_username
  db_password             = var.db_password
  keycloak_admin_password = var.keycloak_admin_password
  acm_certificate_arn     = var.acm_certificate_arn
  public_hostname         = var.public_hostname
}

module "frontend" {
  source = "./modules/frontend"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name              = var.project_name
  alb_dns_name      = module.ecs.alb_dns_name
  alb_https_enabled = var.acm_certificate_arn != null
  public_hostname   = var.public_hostname
}

# --- GitHub Actions: rol IAM asumible via OIDC (sin llaves de AWS de larga --
# duracion guardadas como secreto en GitHub). Solo se crea si se define
# var.github_repository (formato "usuario/repo"); mientras tanto queda en null
# y estos recursos no existen. Nota: AWS solo permite UN proveedor OIDC por URL
# por cuenta -- si mas adelante otro proyecto en esta misma cuenta tambien
# necesita autenticar GitHub Actions, hay que reusar este mismo recurso en vez
# de duplicarlo.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_repository != null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Thumbprint publico y estable de la CA raiz que usa GitHub para este
  # endpoint OIDC (no es un secreto, es el mismo para cualquier cuenta AWS).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_trust" {
  count = var.github_repository != null ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Solo el branch "main" del repo indicado puede asumir el rol.
    # Desde julio 2026 GitHub usa un formato de "sub" con IDs numericos
    # inmutables para repos nuevos: "repo:owner@OWNER_ID/repo@REPO_ID:ref:...",
    # en vez del viejo "repo:owner/repo:ref:...". Se aceptan los dos formatos
    # (el wildcard cubre el "@<id>" opcional) para no depender de cual le toco
    # a este repo en particular.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${split("/", var.github_repository)[0]}@*/${split("/", var.github_repository)[1]}@*:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = var.github_repository != null ? 1 : 0

  name               = "${var.project_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust[0].json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  count = var.github_repository != null ? 1 : 0

  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [module.ecs.ecr_repository_arn, module.ecs.keycloak_ecr_repository_arn]
  }

  statement {
    sid       = "EcsForceRedeploy"
    effect    = "Allow"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [module.ecs.backend_service_arn, module.ecs.keycloak_service_arn]
  }

  statement {
    sid       = "FrontendUpload"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [module.frontend.bucket_arn, "${module.frontend.bucket_arn}/*"]
  }

  statement {
    sid       = "CloudFrontInvalidate"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [module.frontend.cloudfront_distribution_arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  count = var.github_repository != null ? 1 : 0

  name   = "${var.project_name}-github-actions-deploy"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.github_actions_permissions[0].json
}
