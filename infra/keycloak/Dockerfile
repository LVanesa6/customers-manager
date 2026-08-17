FROM quay.io/keycloak/keycloak:25.0

COPY realm-export.json /opt/keycloak/data/import/realm-export.json
COPY themes/customers-theme /opt/keycloak/themes/customers-theme

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
# --http-enabled=true: la terminacion TLS ocurre en CloudFront, no aqui, asi que
# el modo produccion de Keycloak necesita permiso explicito para servir por HTTP.
# --hostname-strict=true: fuerza a Keycloak a usar SIEMPRE el hostname fijado por
# KC_HOSTNAME (variable de entorno del task de ECS) para armar todas sus URLs,
# incluida la del formulario de login -- sin esto, Keycloak intenta adivinar el
# hostname del request entrante y termina usando el DNS interno del ALB (que
# CloudFront no reescribe hacia su propio dominio publico).
# --proxy-headers=xforwarded: un Lambda@Edge (origin-request) inyecta
# X-Forwarded-Host/X-Forwarded-Proto antes de que la peticion llegue al ALB,
# ya que las CloudFront Functions no pueden establecer esos headers.
CMD ["start", "--http-enabled=true", "--http-relative-path=/auth", "--proxy-headers=xforwarded", "--hostname-strict=true", "--import-realm"]
