import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { Router, RouterLink } from '@angular/router';

import { UserService } from '../user.service';
import { AuthService, roleDescription } from '../../../core/auth/auth.service';
import { AppRole, AppUser } from '../../../shared/models/user.model';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog.component';

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [
    FormsModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatToolbarModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatDialogModule,
    MatTooltipModule,
    RouterLink,
  ],
  templateUrl: './user-list.component.html',
  styleUrl: './user-list.component.scss',
})
export class UserListComponent implements OnInit {
  private readonly userService = inject(UserService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  readonly roleDescription = roleDescription;

  readonly roles: AppRole[] = ['USER', 'MANAGER', 'ADMIN'];
  readonly displayedColumns = ['username', 'name', 'email', 'role', 'actions'];
  readonly users = signal<AppUser[]>([]);
  readonly loading = signal(false);
  readonly loadError = signal(false);

  readonly search = signal('');
  readonly roleFilter = signal<AppRole | ''>('');

  readonly filteredUsers = computed(() => {
    const search = this.search().trim().toLowerCase();
    const role = this.roleFilter();

    return this.users().filter((user) => {
      const matchesSearch =
        !search ||
        user.username.toLowerCase().includes(search) ||
        user.email.toLowerCase().includes(search) ||
        `${user.firstName} ${user.lastName}`.toLowerCase().includes(search);
      const matchesRole = !role || user.role === role;
      return matchesSearch && matchesRole;
    });
  });

  ngOnInit(): void {
    this.load();
  }

  clearFilters(): void {
    this.search.set('');
    this.roleFilter.set('');
  }

  load(): void {
    this.loading.set(true);
    this.loadError.set(false);
    this.userService.findAll().subscribe({
      next: (users) => {
        this.users.set(users);
        this.loading.set(false);
      },
      error: () => {
        this.loadError.set(true);
        this.snackBar.open('Error al cargar los usuarios', 'Cerrar', { duration: 3000 });
        this.loading.set(false);
      },
    });
  }

  edit(user: AppUser): void {
    this.router.navigate(['/admin/users', user.id, 'edit']);
  }

  remove(user: AppUser): void {
    const dialogRef = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Eliminar usuario',
        message: `Se eliminara a "${user.username}". Esta accion no se puede deshacer.`,
      },
    });

    dialogRef.afterClosed().subscribe((confirmed) => {
      if (!confirmed) {
        return;
      }
      this.userService.delete(user.id).subscribe({
        next: () => {
          this.snackBar.open('Usuario eliminado', 'Cerrar', { duration: 3000 });
          this.load();
        },
        error: (err) => {
          const message = err.error?.message ?? 'No se pudo eliminar el usuario';
          this.snackBar.open(message, 'Cerrar', { duration: 4000 });
        },
      });
    });
  }
}
