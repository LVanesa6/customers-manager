data "aws_region" "current" {}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.name}-backend"
  image_tag_mutability = "MUTABLE"
  # Sin esto, "terraform destroy" falla si el repo tiene imagenes adentro
  # (que siempre las va a tener, porque el flujo de deploy sube al menos ":latest").
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Repo para una imagen de Keycloak personalizada (con el realm-export.json y el
# tema de login ya incluidos) -- la imagen oficial no trae forma de montar esos
# archivos en ECS Fargate como si fuera un volumen de docker-compose.
resource "aws_ecr_repository" "keycloak" {
  name                 = "${var.name}-keycloak"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

locals {
  backend_image  = coalesce(var.backend_image, "${aws_ecr_repository.backend.repository_url}:latest")
  keycloak_image = coalesce(var.keycloak_image, "${aws_ecr_repository.keycloak.repository_url}:latest")
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- Security groups -------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Trafico entrante publico hacia el ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Solo se usa si se provee acm_certificate_arn; dejarlo abierto no representa
  # riesgo adicional ya que sin certificado no hay listener escuchando en 443.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks-sg"
  description = "Trafico desde el ALB hacia las tasks de ECS (backend y keycloak)"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-tasks-sg" }
}

# --- Load balancer -----------------------------------------------------

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "keycloak" {
  name        = "${var.name}-keycloak-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    # Keycloak sirve todo bajo /auth (--http-relative-path=/auth), asi que el
    # healthcheck debe apuntar ahi -- "/" no existe y devuelve 404.
    path                = "/auth/realms/master"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

locals {
  https_enabled           = var.acm_certificate_arn != null
  forwarding_listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # Sin certificado ACM (default, sin dominio real): sirve HTTP directo, util para
  # probar el stack. Con certificado: redirige todo a HTTPS y el forwarding real
  # ocurre en el listener 443 (ver aws_lb_listener.https).
  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = local.forwarding_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      # /actuator/* tambien va al backend: Spring Boot Actuator expone
      # /actuator/health y /actuator/info en la raiz, no bajo /api.
      values = ["/api/*", "/actuator/*"]
    }
  }
}

resource "aws_lb_listener_rule" "keycloak" {
  listener_arn = local.forwarding_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*"]
    }
  }
}

# --- IAM ---------------------------------------------------------------

resource "aws_iam_role" "execution" {
  name = "${var.name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# --- Logs ----------------------------------------------------------------

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}-backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "keycloak" {
  name              = "/ecs/${var.name}-keycloak"
  retention_in_days = 14
}

# --- Task definitions ------------------------------------------------------

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name         = "backend"
      image        = local.backend_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      environment = [
        # El stack en la nube corre siempre con el perfil "prod" (nombre de app y
        # mensaje de log distintos a los de dev), pero se fija SERVER_PORT=8080 para
        # no tener que tocar el listener del ALB / security groups de este modulo,
        # que ya estan cableados a 8080.
        { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
        { name = "SERVER_PORT", value = "8080" },
        { name = "DB_HOST", value = var.db_endpoint },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password },
        {
          name = "KEYCLOAK_ISSUER_URI"
          # Debe ser EXACTAMENTE el mismo valor que Keycloak pone en el claim "iss"
          # de sus tokens (controlado por KC_HOSTNAME en el container de keycloak).
          # Usa "https" porque ese es el esquema que el NAVEGADOR realmente ve (via
          # CloudFront, que fuerza HTTPS con el usuario final) -- KC_HOSTNAME con un
          # esquema explicito hace que Keycloak arme sus URLs publicas (incluida la
          # action del form de login) con ese valor fijo, sin importar que el tramo
          # interno CloudFront->ALB sea HTTP.
          value = var.public_hostname != null ? "https://${var.public_hostname}/auth/realms/customers-realm" : "http://${aws_lb.this.dns_name}/auth/realms/customers-realm"
        },
        {
          name = "KEYCLOAK_JWK_SET_URI"
          # Descarga las llaves publicas directo del ALB (bypass de CloudFront /
          # Lambda@Edge) -- esta es una llamada servidor-a-servidor, no necesita
          # pasar por el CDN, y evita cualquier inconsistencia de propagacion o
          # de reescritura de headers en el camino.
          value = "http://${aws_lb.this.dns_name}/auth/realms/customers-realm/protocol/openid-connect/certs"
        },
        {
          name = "CORS_ALLOWED_ORIGINS"
          # El navegador siempre ve el sitio via CloudFront en HTTPS (viewer_protocol_policy
          # = redirect-to-https), aunque el tramo interno CloudFront->ALB sea HTTP. El
          # header Origin que Spring valida es el que el navegador realmente envia.
          value = var.public_hostname != null ? "https://${var.public_hostname}" : "http://localhost:4200"
        },
        {
          name = "KEYCLOAK_ADMIN_BASE_URI"
          # El backend usa esto para pedir un token de cuenta de servicio y hablar
          # con la Admin REST API de Keycloak (listar/crear/editar usuarios). Es
          # trafico servidor-a-servidor, va directo al ALB interno, sin pasar por
          # CloudFront. Sin esta variable cae al default de application.yml
          # (localhost:8081, solo valido en docker-compose local) y el backend
          # tira ResourceAccessException / ConnectException en /api/admin/users.
          value = "http://${aws_lb.this.dns_name}/auth"
        },
        {
          name  = "KEYCLOAK_ADMIN_CLIENT_ID"
          value = "customers-admin-service"
        },
        {
          # Coincide con el "secret" del cliente confidencial customers-admin-service
          # en infra/keycloak/realm-export.json (mismo valor que usa docker-compose
          # en local para KEYCLOAK_ADMIN_CLIENT_SECRET).
          name  = "KEYCLOAK_ADMIN_CLIENT_SECRET"
          value = "5bd63edb5986aba7714da342d53969055f7488ce05ec5ebb"
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "keycloak" {
  family                   = "${var.name}-keycloak"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.keycloak_cpu
  memory                   = var.keycloak_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "keycloak"
      image     = local.keycloak_image
      essential = true
      # El comando de arranque (incluyendo --import-realm) vive en el CMD de la
      # imagen personalizada (infra/keycloak/Dockerfile), no se sobreescribe aqui.
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      environment = concat([
        { name = "KEYCLOAK_ADMIN", value = "admin" },
        { name = "KEYCLOAK_ADMIN_PASSWORD", value = var.keycloak_admin_password },
        { name = "KC_DB", value = "mysql" },
        { name = "KC_DB_URL", value = "jdbc:mysql://${var.db_endpoint}:${var.db_port}/keycloak" },
        { name = "KC_DB_USERNAME", value = var.db_username },
        { name = "KC_DB_PASSWORD", value = var.db_password },
        ], var.public_hostname != null ? [
        # Sin esto, Keycloak arma sus URLs de login con el hostname interno del
        # ALB (el unico que ve, ya que CloudFront reescribe el header Host hacia
        # el origin) en vez del dominio publico real por el que entran los usuarios.
        # Esquema "https" a proposito: es lo que el navegador ve de verdad (CloudFront
        # fuerza HTTPS con el usuario final); si se deja "http" aca, Keycloak genera
        # la action del <form> de login como http://, y el navegador tira la
        # advertencia nativa de "esta informacion no es segura" al enviar el login.
        { name = "KC_HOSTNAME", value = "https://${var.public_hostname}/auth" }
      ] : [])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.keycloak.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "keycloak"
        }
      }
    }
  ])
}

# --- Services ------------------------------------------------------------

resource "aws_ecs_service" "backend" {
  name            = "${var.name}-backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Spring Boot en esta task (256 CPU units) tarda ~110s en arrancar del todo;
  # sin este grace period el ALB lo marca "unhealthy" y lo mata antes de que
  # termine de iniciar, causando un crash-loop permanente.
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.backend]
}

resource "aws_ecs_service" "keycloak" {
  name            = "${var.name}-keycloak"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.keycloak.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Mismo motivo que el servicio de backend -- Keycloak tambien tarda en arrancar.
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.keycloak]
}
