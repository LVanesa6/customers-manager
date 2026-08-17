#!/bin/sh
set -e

# El backend escucha en un puerto distinto segun su perfil de Spring (8080 en
# dev, 9090 en prod -- ver application-dev.yml / application-prod.yml). Este
# contenedor recibe la misma variable BACKEND_PROFILE que el backend y arma
# la config real de nginx apuntando al puerto que corresponda, para que el
# cambio de ambiente sea de verdad (no solo cosmetico) tambien corriendo por
# docker, sin tener que sacar el jar del contenedor.
if [ "$BACKEND_PROFILE" = "prod" ]; then
  export BACKEND_PORT=9090
else
  export BACKEND_PORT=8080
fi

echo "nginx: enrutando /api y /actuator hacia backend:${BACKEND_PORT} (BACKEND_PROFILE=${BACKEND_PROFILE:-dev})"

envsubst '${BACKEND_PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
