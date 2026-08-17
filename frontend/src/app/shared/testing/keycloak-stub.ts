import { Provider } from '@angular/core';
import Keycloak from 'keycloak-js';

/**
 * Stub minimo de Keycloak para pruebas de componentes que usan HasRolesDirective
 * o AuthService, sin depender de un servidor Keycloak real.
 */
export function provideKeycloakStub(roles: string[] = ['ADMIN', 'USER']): Provider {
  return {
    provide: Keycloak,
    useValue: {
      authenticated: true,
      realmAccess: { roles },
      resourceAccess: {},
      tokenParsed: { preferred_username: 'test-user' },
      login: jest.fn(),
      logout: jest.fn(),
    },
  };
}
