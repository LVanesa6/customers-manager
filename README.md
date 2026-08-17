# Customers Manager

App full-stack para el registro y consulta de clientes (CRUD). La arme como proyecto de
portafolio, tratando de aplicar cosas que se ven en un backend real: arquitectura por
capas con DTO/Mapper, autenticacion centralizada con Keycloak (nada de manejar passwords
a mano), perfiles de ejecucion separados para dev y prod, y despliegue en AWS con Terraform.

## Stack

| Capa       | Tecnologia |
|------------|------------|
| Backend    | Java 21, Spring Boot 3, Spring Data JPA, Spring Security (OAuth2 Resource Server), MapStruct, springdoc-openapi |
| Frontend   | Angular 19 (standalone components, signals), Angular Material, keycloak-angular |
| Auth       | Keycloak (realm `customers-realm`) |
| Base de datos | MySQL 8 |
| Tests      | JUnit 5 + Mockito + Testcontainers (backend), Jest + Testing Library (frontend) |
| Infraestructura | Docker Compose para local, Terraform + AWS (ECS Fargate, RDS, CloudFront) para la nube |

## Como esta organizado

```
/
├── backend/          Spring Boot API REST (clientes)
│   └── src/main/resources/
│       ├── application.yml       # config comun (datasource, seguridad, cors)
│       ├── application-dev.yml   # puerto 8080, nombre "customers-dev"
│       └── application-prod.yml  # puerto 9090, nombre "customers-prod"
├── frontend/          Angular SPA
├── infra/
│   ├── keycloak/     realm-export.json (realm, roles y usuarios de prueba)
│   ├── mysql/        script de inicializacion de bases de datos
│   └── terraform/    IaC para AWS (ver infra/terraform/README.md)
└── docker-compose.yml
```

## Endpoints principales

| Metodo | Ruta | Rol requerido |
|--------|------|----------------|
| `POST` | `/api/customers` | ADMIN o MANAGER |
| `GET` | `/api/customers` | cualquier usuario autenticado (paginado, filtro opcional `?name=`) |
| `GET` | `/api/customers/{id}` | cualquier usuario autenticado |
| `PUT` | `/api/customers/{id}` | ADMIN o MANAGER |
| `DELETE` | `/api/customers/{id}` | ADMIN |

Body de ejemplo para crear un cliente:

```json
{
  "name": "Juan Perez",
  "email": "juan@email.com",
  "phone": "3001234567",
  "address": "Calle 1 # 2-34"
}
```

## Dev y prod, pero de verdad

El backend usa perfiles reales de Spring Boot que cambian cosas
que se notan: el puerto donde escucha, el nombre de la app, cuanto loguea, y si Swagger
queda expuesto o no.

| Ambiente | Puerto | Nombre app | Mensaje de log |
|----------|--------|------------|-----------------|
| `dev`    | 8080   | `customers-dev`  | `Ejecutando en DEV` |
| `prod`   | 9090   | `customers-prod` | `Ejecutando en PROD` |

Si no se pasa ningun perfil, arranca en `dev` (queda asi por defecto en `application.yml`).

## Compilar

```bash
cd backend
mvn clean package
```

Deja el ejecutable en `backend/target/app.jar`.

## Correrlo suelto

```bash
# Modo dev (puerto 8080)
java -jar backend/target/app.jar --spring.profiles.active=dev

# Modo prod (puerto 9090, simulado)
java -jar backend/target/app.jar --spring.profiles.active=prod
```

Al arrancar, la consola muestra el mensaje del perfil activo junto con el nombre de la
app y el puerto:

```
INFO ... c.c.c.CustomersServiceApplication : Ejecutando en DEV | app=customers-dev | port=8080
```

El backend necesita MySQL corriendo para terminar de levantar del todo (sin base de
datos falla al inicializar JPA), pero el puerto y el mensaje del perfil ya se alcanzan a
ver en consola aunque la conexion a la base falle.

## Levantar el entorno local completo

```bash
# 1. Infraestructura base (MySQL + Keycloak)
docker compose up -d mysql keycloak

# 2. Backend (requiere Java 21 + Maven), modo dev
cd backend
mvn spring-boot:run -Dspring-boot.run.profiles=dev
# Swagger UI: http://localhost:8080/swagger-ui.html

# 3. Frontend (requiere Node 22)
cd frontend
npm install
npm start
# App: http://localhost:4200
```

Los usuarios de prueba estan en `infra/keycloak/realm-export.json`, con roles compuestos
(ADMIN incluye MANAGER, que a su vez incluye USER):

| Usuario  | Password    | Rol     | Permisos |
|----------|-------------|---------|----------|
| admin    | admin123    | ADMIN   | Leer, crear/editar y **eliminar** clientes |
| manager  | manager123  | MANAGER | Leer, crear y editar (no puede eliminar) |
| user     | user123     | USER    | Solo lectura |

El login usa un tema propio (`infra/keycloak/themes/customers-theme`) en vez del look
por defecto de Keycloak.

Tambien se puede levantar todo de una (frontend y backend dockerizados, backend en modo dev):

```bash
docker compose --profile full up -d --build
```

Y si quieres probar el ambiente `prod` completo en local (puerto 9090, `ddl-auto: validate`,
Swagger apagado, logs mas silenciosos), es la misma orden pasando `BACKEND_PROFILE=prod` --
el frontend tambien lee esa variable para saber a que puerto del backend enrutar:

```bash
BACKEND_PROFILE=prod docker compose --profile full up -d --build
```

## Tests

```bash
# Backend: unitarias (Mockito) + integracion (Testcontainers + MySQL real)
cd backend && mvn test

# Frontend: unitarias (Jest)
cd frontend && npm test
```

## Despliegue en AWS

La arquitectura completa, los pasos de despliegue estan en [infra/terraform/README.md](infra/terraform/README.md).
En la nube el backend siempre corre con el perfil `prod` (ECS fija
`SPRING_PROFILES_ACTIVE=prod`).

Esto esta desplegado ahora mismo en una cuenta real de AWS (ECS Fargate + RDS + CloudFront)
y se probo su funcionamiento: login, CRUD completo desde el navegador. Cuando se destruya
para no seguir pagando, la guia para volver a levantarlo esta en ese mismo README.
