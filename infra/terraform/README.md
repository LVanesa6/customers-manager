# Infraestructura AWS (Terraform)

Despliega el stack completo en AWS: ECS Fargate para el backend y Keycloak, RDS MySQL,
y CloudFront + S3 para el frontend Angular.

**Estado actual: corriendo en una cuenta real de AWS**, con el dominio
`d15pfta40bgzwd.cloudfront.net`.

## Arquitectura

- `modules/vpc`: VPC con subnets publicas y privadas en 2 AZs, mas un NAT gateway.
- `modules/rds`: RDS MySQL en las subnets privadas, con `storage_encrypted = true` y las
  credenciales guardadas tambien en Secrets Manager.
- `modules/ecs`: cluster ECS Fargate con los servicios `backend` y `keycloak`, un ALB con
  reglas de path (`/api/*` y `/auth/*`), y un repo ECR por cada imagen.
- `modules/frontend`: bucket S3 privado (con Origin Access Control) detras de CloudFront,
  con comportamientos extra que enrutan `/api/*` y `/auth/*` hacia el ALB, y una
  CloudFront Function + un Lambda@Edge para un par de problemas puntuales que se explican
  mas abajo.

Todo corre en `us-east-1` en el state actual. La unica excepcion es que el Lambda@Edge y
la CloudFront Function tienen que existir en `us-east-1` si o si (lo exige AWS), asi que
`versions.tf` declara un segundo provider `aws.us_east_1` aunque el resto del stack use
la misma region de todas formas.

## Desplegar desde cero (despues de un destroy)

```bash
cd infra/terraform

# 1. Credenciales -- nunca las dejes en un archivo, solo como variable de entorno de la sesion
export TF_VAR_db_password="una-password-segura"
export TF_VAR_keycloak_admin_password="otra-password-segura"

# 2. Inicializar y aplicar
terraform init
terraform plan -out=tfplan.out
terraform apply tfplan.out
rm -f tfplan.out
```

Con esto queda creada la infraestructura, pero todavia no hay nada corriendo de verdad:
los servicios de ECS van a crashear en bucle hasta que subas imagenes reales, y el
frontend ni siquiera existe en S3 todavia. Faltan los pasos 3 a 7.

```bash
# 3. Build + push de la imagen del backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ecr_repository_url>
docker build --platform linux/amd64 -t <ecr_repository_url>:latest ../../backend
docker push <ecr_repository_url>:latest

# 4. Build + push de la imagen de Keycloak personalizada (con el realm y el tema ya adentro)
docker build --platform linux/amd64 -t <keycloak_ecr_repository_url>:latest ../keycloak
docker push <keycloak_ecr_repository_url>:latest

# 5. Forzar que los dos servicios de ECS tomen las imagenes nuevas
aws ecs update-service --cluster cuso-customers-cluster --service cuso-customers-backend --force-new-deployment
aws ecs update-service --cluster cuso-customers-cluster --service cuso-customers-keycloak --force-new-deployment

# 6. Crear la base "keycloak" en el RDS -- el modulo de RDS solo crea la base nombrada en
#    terraform.tfvars, y Keycloak necesita una aparte. Como el RDS es privado no hay forma
#    de correr un CREATE DATABASE a mano desde tu laptop; hace falta lanzar una task ECS
#    efimera (cliente mysql) en la misma VPC que lo haga por vos.

# 7. Build + upload del frontend Angular
cd ../../frontend
npx ng build --configuration production
aws s3 sync dist/frontend/browser s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

Y falta un ultimo detalle antes de que el login funcione bien:

```bash
# 8. Segundo apply, ahora con public_hostname
# El primer apply (paso 2) no puede saber de antemano el dominio de CloudFront, porque
# se genera en ese mismo apply. Una vez tengas el output "cloudfront_domain_name", corre
# un SEGUNDO apply pasando esa variable -- esto activa el listener HTTPS opcional, el
# KC_HOSTNAME de Keycloak, el CORS del backend, y el Lambda@Edge.
export TF_VAR_public_hostname="<cloudfront_domain_name del output>"
terraform plan -out=tfplan.out
terraform apply tfplan.out
rm -f tfplan.out

# 9. Actualizar redirectUris/webOrigins del realm de Keycloak (infra/keycloak/realm-export.json)
#    con el dominio real de CloudFront, reconstruir la imagen de Keycloak (paso 4 otra vez),
#    y forzar el deployment de nuevo (paso 5 otra vez).
```

## Cifrado

- **En reposo**: el RDS tiene `storage_encrypted = true` (KMS administrada por AWS,
  alias `aws/rds`).
- **En transito, backend → RDS**: la app fuerza SSL en la conexion JDBC
  (`useSSL=true&requireSSL=true`, ver `backend/src/main/resources/application.yml`).
- **En transito, usuario → CloudFront**: siempre HTTPS (certificado default de CloudFront).
- **En transito, CloudFront → ALB**: HTTP por defecto. Para HTTPS de punta a punta hace
  falta un dominio propio, porque ACM valida el certificado contra DNS:

  ```bash
  aws acm request-certificate --domain-name api.tudominio.com --validation-method DNS --region us-east-1
  # agregar el CNAME de validacion en tu proveedor DNS, esperar a que quede "ISSUED"
  export TF_VAR_acm_certificate_arn="arn:aws:acm:us-east-1:123456789012:certificate/xxxx"
  terraform apply
  ```

## CI/CD con GitHub Actions

Con la infraestructura ya arriba (seccion de mas arriba), el dia a dia -- cambios de
codigo en `backend/`, `frontend/` o `infra/keycloak/` -- se actualiza solo con GitHub
Actions (`.github/workflows/deploy.yml`), sin volver a tocar Terraform para eso. El
workflow construye lo que cambio, lo publica (ECR o S3 + CloudFront segun el caso) y
fuerza el redeploy del servicio de ECS correspondiente. A proposito nunca corre
`terraform apply`: la infraestructura se sigue manejando a mano, que para un proyecto de
este tamano es mas seguro que darle a CI permiso para crear o borrar VPCs, bases de
datos, etc.

### Configuracion inicial (una sola vez por cuenta de AWS / repo de GitHub)

1. Define `github_repository` (formato `"usuario/repo"`, tu cuenta personal de GitHub,
   no una corporativa) en `terraform.tfvars` o como `TF_VAR_github_repository`, y volve
   a aplicar:

   ```bash
   export TF_VAR_github_repository="tu-usuario/customers-manager"
   terraform plan -out=tfplan.out
   terraform apply tfplan.out
   ```

   Esto crea (si todavia no existian en la cuenta) el proveedor OIDC de GitHub
   (`aws_iam_openid_connect_provider.github`) y un rol IAM
   (`${project_name}-github-actions-deploy`) que solo puede asumir el branch `main` de
   ese repo, con permisos minimos: push a los dos repos ECR, forzar el redeploy de los
   dos servicios de ECS, subir al bucket S3 del frontend, e invalidar la distribucion de
   CloudFront. No usa (ni necesita) un access key/secret key de larga duracion.

2. El output `github_actions_role_arn` se guarda como secreto en el repo de GitHub
   (Settings → Secrets and variables → Actions → New repository secret), con el nombre
   `AWS_DEPLOY_ROLE_ARN`.

3. Igual con el output `cloudfront_distribution_id`, como secreto
   `CLOUDFRONT_DISTRIBUTION_ID` (algo como `E1A2B3C4D5EFGH`).

   El nombre del bucket S3 y el del cluster/servicios de ECS no hacen falta como
   secreto -- son predecibles a partir de `PROJECT_NAME` y ya estan hardcodeados en el
   workflow.

De ahi en adelante, cualquier push a `main` que toque `backend/**`, `frontend/**` o
`infra/keycloak/**` dispara solo el job que corresponde (usa `dorny/paths-filter` para
no reconstruir todo en cada push).

## Como destruir todo (para no seguir pagando)

```bash
cd infra/terraform
export TF_VAR_db_password="la-que-uses"
export TF_VAR_keycloak_admin_password="la-que-uses"
export TF_VAR_public_hostname="d15pfta40bgzwd.cloudfront.net"   # el actual, o el que tengas

terraform destroy
```

Los dos repos ECR ya tienen `force_delete = true` y el bucket S3 del frontend
`force_destroy = true`, asi que el destroy no se traba por tener imagenes o archivos
adentro (antes de agregar esto, esos dos recursos fallaban si no se vaciaban a mano primero).

Cosas a tener en cuenta:
- El secret de Secrets Manager (`cuso-customers-db-credentials`) queda en estado
  "pending deletion" durante 7 a 30 dias (es el recovery window de AWS), no se borra al
  instante. No genera costo real mientras tanto, es normal que quede ahi.
- CloudFront tarda varios minutos en terminar de "deshabilitarse" antes de poder
  borrarse de verdad. `terraform destroy` espera eso solo, puede tardar entre 5 y 15
  minutos en esa parte.
- El Lambda@Edge (`aws_lambda_function.forwarded_headers`) casi seguro va a fallar en el
  primer intento, con `InvalidParameterValueException: ... because it is a replicated
  function`. No es un bug del proyecto, es una limitacion de AWS: cuando un Lambda esta
  asociado a CloudFront, AWS lo replica a todos los edge locations del mundo, y no deja
  borrar el original hasta que esas replicas terminan de limpiarse solas (puede tardar
  desde minutos hasta un par de horas despues de que la distribucion ya se borro). El
  resto de los recursos (RDS, ECS, VPC, ALB, todo lo que realmente factura) se borra
  bien igual, solo quedan pendientes el Lambda y su rol IAM. Alcanza con volver a correr
  `terraform destroy` mas tarde con las mismas variables para terminar de limpiar esos
  dos ultimos recursos -- no generan costo mientras tanto (un Lambda sin invocaciones
  cuesta $0).
- Despues del destroy, para volver a desplegar hay que seguir la seccion "Desplegar
  desde cero" de mas arriba. El dominio de CloudFront que te va a tocar es distinto al
  anterior, asi que hay que repetir el segundo apply con el `public_hostname` nuevo y
  actualizar el realm de Keycloak con ese dominio.


