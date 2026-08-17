resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}

# Ingreso restringido por CIDR (en vez de security group cruzado) para evitar una
# dependencia circular entre este modulo y el modulo ECS: las subnets privadas solo
# alojan las tasks de backend/Keycloak, por lo que el CIDR ya acota el acceso.
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Permite acceso MySQL solo desde las subnets privadas de la aplicacion"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-db-sg"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.name}-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name}-mysql"
  engine                  = "mysql"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
  multi_az                = false

  # Cifrado en reposo con la llave administrada por AWS para RDS (alias aws/rds).
  storage_encrypted = true

  tags = {
    Name = "${var.name}-mysql"
  }
}
