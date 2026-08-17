import { Component, OnInit, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, map, of, switchMap } from 'rxjs';

import { UserService } from '../user.service';
import { AppRole, AppUser } from '../../../shared/models/user.model';

@Component({
  selector: 'app-user-form',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatButtonModule,
    MatIconModule,
    MatToolbarModule,
  ],
  templateUrl: './user-form.component.html',
  styleUrl: './user-form.component.scss',
})
export class UserFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly userService = inject(UserService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);

  readonly roles: AppRole[] = ['USER', 'MANAGER', 'ADMIN'];
  readonly userId = signal<string | null>(null);
  readonly saving = signal(false);
  readonly viewMode = signal(false);

  private lastSaved: AppUser | null = null;

  readonly form = this.fb.nonNullable.group({
    username: ['', [Validators.required, Validators.maxLength(100)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
    firstName: ['', [Validators.required, Validators.maxLength(100)]],
    lastName: ['', [Validators.required, Validators.maxLength(100)]],
    password: [''],
    role: ['USER' as AppRole, [Validators.required]],
  });

  ngOnInit(): void {
    const idParam = this.route.snapshot.paramMap.get('id');
    if (!idParam) {
      this.form.controls.password.addValidators([Validators.required, Validators.minLength(6)]);
      return;
    }

    this.userId.set(idParam);
    this.form.controls.password.addValidators([Validators.minLength(6)]);

    this.userService.findAll().subscribe((users) => {
      const user = users.find((u) => u.id === idParam);
      if (!user) {
        return;
      }
      this.lastSaved = user;
      this.patchForm(user);
      this.viewMode.set(true);
      this.form.disable();
    });
  }

  private patchForm(user: AppUser): void {
    this.form.patchValue({
      username: user.username,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      password: '',
      role: user.role ?? 'USER',
    });
  }

  enableEdit(): void {
    this.viewMode.set(false);
    this.form.enable();
    this.form.controls.username.disable();
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.snackBar.open('Revisa los campos marcados en rojo', 'Cerrar', { duration: 3000 });
      return;
    }

    this.saving.set(true);
    const raw = this.form.getRawValue();
    const id = this.userId();

    const operation$: Observable<void> = id
      ? this.userService.update(id, {
          email: raw.email,
          firstName: raw.firstName,
          lastName: raw.lastName,
          role: raw.role,
        }).pipe(
          switchMap(() => (raw.password ? this.userService.resetPassword(id, raw.password) : of(undefined))),
        )
      : this.userService.create({
          username: raw.username,
          email: raw.email,
          firstName: raw.firstName,
          lastName: raw.lastName,
          password: raw.password,
          role: raw.role,
        }).pipe(map(() => undefined));

    operation$.subscribe({
      next: () => {
        this.saving.set(false);
        this.snackBar.open('Usuario guardado', 'Cerrar', { duration: 3000 });
        if (id) {
          this.lastSaved = { id, username: raw.username, email: raw.email, firstName: raw.firstName, lastName: raw.lastName, role: raw.role };
          this.patchForm(this.lastSaved);
          this.viewMode.set(true);
          this.form.disable();
        } else {
          this.router.navigate(['/admin/users']);
        }
      },
      error: (err: HttpErrorResponse) => {
        this.saving.set(false);
        const apiError = err.error as { message?: string; details?: string[] } | null;
        const message = apiError?.details?.length
          ? apiError.details.join(' | ')
          : (apiError?.message ?? 'No se pudo guardar el usuario');
        this.snackBar.open(message, 'Cerrar', { duration: 4000 });
      },
    });
  }

  cancel(): void {
    if (this.userId() && this.lastSaved) {
      this.patchForm(this.lastSaved);
      this.viewMode.set(true);
      this.form.disable();
      return;
    }
    this.router.navigate(['/admin/users']);
  }

  goBack(): void {
    this.router.navigate(['/admin/users']);
  }
}
