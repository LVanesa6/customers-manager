export const environment = {
  production: false,
  apiBaseUrl: 'http://localhost:8080/api',
  actuatorBaseUrl: 'http://localhost:8080/actuator',
  keycloak: {
    url: 'http://localhost:8081/auth',
    realm: 'customers-realm',
    clientId: 'customers-app',
  },
};
