import { createAuthGuard, AuthGuardData } from 'keycloak-angular';
import { CanActivateFn } from '@angular/router';

const isAccessAllowed = async (
  _route: unknown,
  _state: unknown,
  authData: AuthGuardData,
): Promise<boolean> => {
  const { authenticated, keycloak } = authData;

  if (authenticated) {
    return true;
  }

  await keycloak.login({
    redirectUri: window.location.href,
  });

  return false;
};

export const authGuard: CanActivateFn = createAuthGuard(isAccessAllowed);
