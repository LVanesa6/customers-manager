export type AppRole = 'USER' | 'MANAGER' | 'ADMIN';

export interface AppUser {
  id: string;
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  role: AppRole | null;
}

export interface CreateUserRequest {
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  password: string;
  role: AppRole;
}

export interface UpdateUserRequest {
  email: string;
  firstName: string;
  lastName: string;
  role: AppRole;
}
