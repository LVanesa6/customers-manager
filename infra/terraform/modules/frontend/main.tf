resource "aws_s3_bucket" "spa" {
  bucket = "${var.name}-frontend"
  # Sin esto, "terraform destroy" falla porque el bucket siempre tiene el build
  # de Angular adentro (subido a mano con "aws s3 sync" despues del apply).
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "spa" {
  bucket                  = aws_s3_bucket.spa.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "spa" {
  name                              = "${var.name}-spa-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "spa_bucket_policy" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.spa.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.spa.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "spa" {
  bucket = aws_s3_bucket.spa.id
  policy = data.aws_iam_policy_document.spa_bucket_policy.json
}

locals {
  s3_origin_id  = "${var.name}-s3-origin"
  alb_origin_id = "${var.name}-alb-origin"
}

# CloudFront reescribe el header Host hacia el dominio del origin (el ALB) en
# cualquier peticion a un custom origin -- no hay forma de evitarlo. Keycloak
# necesita el dominio publico real para armar sus URLs de login. Se resuelve con
# un Lambda@Edge en el evento origin-request: las CloudFront Functions (mas
# simples/baratas) NO alcanzan porque tienen prohibido establecer X-Forwarded-Host
# y X-Forwarded-Proto.
data "archive_file" "forwarded_headers" {
  count       = var.public_hostname != null ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.build/forwarded-headers.zip"

  source {
    filename = "index.js"
    content = templatefile("${path.module}/forwarded-headers-edge.js.tmpl", {
      public_hostname = var.public_hostname
    })
  }
}

resource "aws_iam_role" "lambda_edge" {
  count = var.public_hostname != null ? 1 : 0
  name  = "${var.name}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_logs" {
  count      = var.public_hostname != null ? 1 : 0
  role       = aws_iam_role.lambda_edge[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "forwarded_headers" {
  count = var.public_hostname != null ? 1 : 0
  # Lambda@Edge exige que la function exista en us-east-1 sin importar la region
  # del resto del stack.
  provider         = aws.us_east_1
  function_name    = "${var.name}-forwarded-headers"
  role             = aws_iam_role.lambda_edge[0].arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.forwarded_headers[0].output_path
  source_code_hash = data.archive_file.forwarded_headers[0].output_base64sha256
  publish          = true
  timeout          = 5
}

# Enrutamiento de SPA: reescribe cualquier ruta sin extension de archivo (ej.
# /customers/new, /customers/5/edit) hacia /index.html ANTES de llegar al origin,
# para que el Angular Router decida que mostrar. Se hace con una CloudFront
# Function (viewer-request) asociada SOLO al default_cache_behavior (S3) -- a
# diferencia de un custom_error_response a nivel de distribucion, esto no
# intercepta los 403/404 legitimos que devuelve el backend via /api/* (por
# ejemplo, un 403 real de @PreAuthorize o un 404 de "recurso no encontrado"),
# que antes quedaban enmascarados como si fueran la pagina de la SPA.
resource "aws_cloudfront_function" "spa_routing" {
  name    = "${var.name}-spa-routing"
  runtime = "cloudfront-js-2.0"
  comment = "Reescribe rutas del Angular Router a /index.html"
  publish = true
  code    = file("${path.module}/spa-routing.js")
}

resource "aws_cloudfront_distribution" "spa" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
  }

  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.alb_https_enabled ? "https-only" : "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = local.alb_origin_id
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled managed policy
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewer managed policy

    dynamic "lambda_function_association" {
      for_each = var.public_hostname != null ? [1] : []
      content {
        event_type = "origin-request"
        lambda_arn = aws_lambda_function.forwarded_headers[0].qualified_arn
      }
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/auth/*"
    target_origin_id         = local.alb_origin_id
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled managed policy
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewer managed policy

    dynamic "lambda_function_association" {
      for_each = var.public_hostname != null ? [1] : []
      content {
        event_type = "origin-request"
        lambda_arn = aws_lambda_function.forwarded_headers[0].qualified_arn
      }
    }
  }

  # El frontend llama a /actuator/info y /actuator/health en la raiz (sin
  # prefijo /api, es donde Spring Boot Actuator los expone por defecto), asi
  # que necesita su propio comportamiento -- sin esto cae al origin S3 por
  # defecto y devuelve el index.html de la SPA en vez del JSON real.
  ordered_cache_behavior {
    path_pattern             = "/actuator/*"
    target_origin_id         = local.alb_origin_id
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled managed policy
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewer managed policy

    dynamic "lambda_function_association" {
      for_each = var.public_hostname != null ? [1] : []
      content {
        event_type = "origin-request"
        lambda_arn = aws_lambda_function.forwarded_headers[0].qualified_arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
