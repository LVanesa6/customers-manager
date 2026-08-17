import { Component, OnInit, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ActivatedRoute, Router } from '@angular/router';
import { HasRolesDirective } from 'keycloak-angular';

import { CustomerService } from '../customer.service';
import { Customer } from '../../../shared/models/customer.model';

@Component({
  selector: 'app-customer-form',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatToolbarModule,
    HasRolesDirective,
  ],
  templateUrl: './customer-form.component.html',
  styleUrl: './customer-form.component.scss',
})
export class CustomerFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly customerService = inject(CustomerService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);

  readonly customerId = signal<number | null>(null);
  readonly saving = signal(false);
  readonly viewMode = signal(false);

  private lastSaved: Customer | null = null;

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.maxLength(150)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
    phone: ['', [Validators.maxLength(30)]],
    address: ['', [Validators.maxLength(200)]],
  });

  ngOnInit(): void {
    const idParam = this.route.snapshot.paramMap.get('id');
    if (!idParam) {
      return;
    }

    const id = Number(idParam);
    this.customerId.set(id);
    this.customerService.findById(id).subscribe((customer) => {
      this.lastSaved = customer;
      this.patchForm(customer);
      this.viewMode.set(true);
      this.form.disable();
    });
  }

  private patchForm(customer: Customer): void {
    this.form.patchValue({
      name: customer.name,
      email: customer.email,
      phone: customer.phone ?? '',
      address: customer.address ?? '',
    });
  }

  enableEdit(): void {
    this.viewMode.set(false);
    this.form.enable();
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.saving.set(true);
    const raw = this.form.getRawValue();
    const request = {
      name: raw.name,
      email: raw.email,
      phone: raw.phone || null,
      address: raw.address || null,
    };
    const id = this.customerId();

    const operation = id ? this.customerService.update(id, request) : this.customerService.create(request);

    operation.subscribe({
      next: (customer) => {
        this.saving.set(false);
        this.snackBar.open('Cliente guardado', 'Cerrar', { duration: 3000 });
        if (id) {
          this.lastSaved = customer;
          this.viewMode.set(true);
          this.form.disable();
        } else {
          this.router.navigate(['/customers']);
        }
      },
      error: (err: HttpErrorResponse) => {
        this.saving.set(false);
        const apiError = err.error as { message?: string; details?: string[] } | null;
        const message = apiError?.details?.length
          ? apiError.details.join(' | ')
          : (apiError?.message ?? 'No se pudo guardar el cliente');
        this.snackBar.open(message, 'Cerrar', { duration: 4000 });
      },
    });
  }

  cancel(): void {
    if (this.customerId() && this.lastSaved) {
      this.patchForm(this.lastSaved);
      this.viewMode.set(true);
      this.form.disable();
      return;
    }
    this.router.navigate(['/customers']);
  }

  goBack(): void {
    this.router.navigate(['/customers']);
  }
}
