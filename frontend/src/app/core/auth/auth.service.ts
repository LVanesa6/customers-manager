import { Injectable, computed, inject, signal } from '@angular/core';
import Keycloak from 'keycloak-js';

export type AppRole = 'ADMIN' | 'MANAGER' | 'USER';

const ROLE_LABELS: Record<AppRole, string> = {
  ADMIN: 'Administrador',
  MANAGER: 'Gestor',
  USER: 'Usuario',
};

const ROLE_DESCRIPTIONS: Record<AppRole, string> = {
  ADMIN: 'Acceso total: crear, editar y eliminar clientes, y gestionar usuarios',
  MANAGER: 'Puede crear y actualizar clientes',
  USER: 'Acceso de solo lectura al catalogo de clientes',
};

export function roleDescription(role: string): string {
  return ROLE_DESCRIPTIONS[role as AppRole] ?? '';
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly keycloak = inject(Keycloak);

  readonly username = signal<string | undefined>(undefined);
  readonly roles = signal<string[]>([]);

  readonly primaryRole = computed<AppRole | null>(() => {
    if (this.hasRole('ADMIN')) return 'ADMIN';
    if (this.hasRole('MANAGER')) return 'MANAGER';
    if (this.hasRole('USER')) return 'USER';
    return null;
  });

  readonly roleLabel = computed(() => {
    const role = this.primaryRole();
    return role ? ROLE_LABELS[role] : '';
  });

  readonly roleDescription = computed(() => {
    const role = this.primaryRole();
    return role ? ROLE_DESCRIPTIONS[role] : '';
  });

  constructor() {
    this.username.set(this.keycloak.tokenParsed?.['preferred_username']);
    this.roles.set(this.keycloak.realmAccess?.roles ?? []);
  }

  hasRole(role: string): boolean {
    return this.roles().includes(role);
  }

  isAdmin(): boolean {
    return this.hasRole('ADMIN');
  }

  logout(): void {
    this.keycloak.logout({ redirectUri: window.location.origin });
  }
}
