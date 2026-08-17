import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { provideNativeDateAdapter } from '@angular/material/core';
import {
  provideKeycloak,
  withAutoRefreshToken,
  AutoRefreshTokenService,
  UserActivityService,
  INCLUDE_BEARER_TOKEN_INTERCEPTOR_CONFIG,
  includeBearerTokenInterceptor,
  type IncludeBearerTokenCondition,
} from 'keycloak-angular';

import { routes } from './app.routes';
import { environment } from '../environments/environment';

const apiBearerCondition: IncludeBearerTokenCondition = {
  urlPattern: new RegExp(`^${environment.apiBaseUrl}(/.*)?$`),
};

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideAnimationsAsync(),
    provideNativeDateAdapter(),
    provideHttpClient(withInterceptors([includeBearerTokenInterceptor])),
    {
      provide: INCLUDE_BEARER_TOKEN_INTERCEPTOR_CONFIG,
      useValue: [apiBearerCondition],
    },
    provideKeycloak({
      config: {
        url: environment.keycloak.url,
        realm: environment.keycloak.realm,
        clientId: environment.keycloak.clientId,
      },
      initOptions: {
        // La app no tiene ninguna ruta publica (todo pasa por authGuard), asi
        // que Keycloak puede resolver la sesion antes de que Angular termine
        // de arrancar, en vez de dejar que el guard de la ruta dispare el
        // login despues de que el header ya se alcanzo a pintar (eso causaba
        // un parpadeo del header/menu antes de la redireccion al login).
        onLoad: 'login-required',
        silentCheckSsoRedirectUri: `${window.location.origin}/silent-check-sso.html`,
        pkceMethod: 'S256',
      },
      features: [withAutoRefreshToken({ onInactivityTimeout: 'logout', sessionTimeout: 60000 })],
      providers: [AutoRefreshTokenService, UserActivityService],
    }),
  ],
};
