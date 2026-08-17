import { Component, OnInit, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router, RouterLink } from '@angular/router';
import { HasRolesDirective } from 'keycloak-angular';

import { CustomerService } from '../customer.service';
import { Customer } from '../../../shared/models/customer.model';
import {
  ConfirmDialogComponent,
} from '../../../shared/components/confirm-dialog/confirm-dialog.component';
import { PaginationComponent } from '../../../shared/components/pagination/pagination.component';

function toIsoDate(value: unknown): string | null {
  if (!(value instanceof Date) || isNaN(value.getTime())) {
    return null;
  }
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

@Component({
  selector: 'app-customer-list',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatToolbarModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatDialogModule,
    RouterLink,
    HasRolesDirective,
    PaginationComponent,
  ],
  templateUrl: './customer-list.component.html',
  styleUrl: './customer-list.component.scss',
})
export class CustomerListComponent implements OnInit {
  private readonly customerService = inject(CustomerService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);
  private readonly router = inject(Router);
  private readonly fb = inject(FormBuilder);

  readonly displayedColumns = ['name', 'email', 'phone', 'address', 'registrationDate', 'actions'];
  readonly customers = signal<Customer[]>([]);
  readonly totalElements = signal(0);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);
  readonly loading = signal(false);
  readonly loadError = signal(false);
  readonly filtersExpanded = signal(false);

  readonly filterForm = this.fb.nonNullable.group({
    name: '',
    email: '',
    phone: '',
    address: '',
    registrationDateFrom: null as Date | null,
    registrationDateTo: null as Date | null,
  });

  ngOnInit(): void {
    this.loadPage();
  }

  toggleFilters(): void {
    this.filtersExpanded.set(!this.filtersExpanded());
  }

  applyFilters(): void {
    this.pageIndex.set(0);
    this.loadPage();
  }

  clearFilters(): void {
    this.filterForm.reset({
      name: '',
      email: '',
      phone: '',
      address: '',
      registrationDateFrom: null,
      registrationDateTo: null,
    });
    this.applyFilters();
  }

  onPageChange(pageIndex: number): void {
    this.pageIndex.set(pageIndex);
    this.loadPage();
  }

  loadPage(): void {
    this.loading.set(true);
    this.loadError.set(false);
    const raw = this.filterForm.getRawValue();
    const filter = {
      name: raw.name,
      email: raw.email,
      phone: raw.phone,
      address: raw.address,
      registrationDateFrom: toIsoDate(raw.registrationDateFrom),
      registrationDateTo: toIsoDate(raw.registrationDateTo),
    };

    this.customerService.findAll(this.pageIndex(), this.pageSize(), filter).subscribe({
      next: (page) => {
        this.customers.set(page.content);
        this.totalElements.set(page.totalElements);
        this.loading.set(false);
      },
      error: () => {
        this.loadError.set(true);
        this.snackBar.open('Error al cargar los clientes', 'Cerrar', { duration: 3000 });
        this.loading.set(false);
      },
    });
  }

  edit(customer: Customer): void {
    this.router.navigate(['/customers', customer.id, 'edit']);
  }

  remove(customer: Customer): void {
    const dialogRef = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Eliminar cliente',
        message: `Se eliminara a "${customer.name}". Esta accion no se puede deshacer.`,
      },
    });

    dialogRef.afterClosed().subscribe((confirmed) => {
      if (!confirmed) {
        return;
      }
      this.customerService.delete(customer.id).subscribe({
        next: () => {
          this.snackBar.open('Cliente eliminado', 'Cerrar', { duration: 3000 });
          this.loadPage();
        },
        error: () => {
          this.snackBar.open('No se pudo eliminar el cliente', 'Cerrar', { duration: 3000 });
        },
      });
    });
  }
}
