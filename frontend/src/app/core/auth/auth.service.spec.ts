import { TestBed } from '@angular/core/testing';

import { AuthService } from './auth.service';
import { provideKeycloakStub } from '../../shared/testing/keycloak-stub';

describe('AuthService', () => {
  function setup(roles: string[]) {
    TestBed.configureTestingModule({
      providers: [AuthService, provideKeycloakStub(roles)],
    });
    return TestBed.inject(AuthService);
  }

  it('exposes the username parsed from the Keycloak token', () => {
    const service = setup(['USER']);

    expect(service.username()).toBe('test-user');
  });

  it('isAdmin returns true when the ADMIN realm role is present', () => {
    expect(setup(['ADMIN', 'USER']).isAdmin()).toBe(true);
  });

  it('isAdmin returns false when the ADMIN realm role is absent', () => {
    expect(setup(['USER']).isAdmin()).toBe(false);
  });

  it('hasRole checks membership in the current realm roles', () => {
    const service = setup(['USER']);

    expect(service.hasRole('USER')).toBe(true);
    expect(service.hasRole('ADMIN')).toBe(false);
  });

  it('primaryRole prioritizes ADMIN over MANAGER and USER when a user has all three', () => {
    expect(setup(['USER', 'MANAGER', 'ADMIN']).primaryRole()).toBe('ADMIN');
  });

  it('primaryRole returns MANAGER when ADMIN is absent but MANAGER is present', () => {
    expect(setup(['USER', 'MANAGER']).primaryRole()).toBe('MANAGER');
  });

  it('primaryRole returns null when no recognized realm role is present', () => {
    expect(setup(['some-other-role']).primaryRole()).toBeNull();
  });
});
