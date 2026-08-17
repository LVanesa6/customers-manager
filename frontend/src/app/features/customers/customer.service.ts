import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { PageResponse } from '../../shared/models/page.model';
import { Customer, CustomerRequest } from '../../shared/models/customer.model';

export interface CustomerFilter {
  name?: string | null;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
  registrationDateFrom?: string | null;
  registrationDateTo?: string | null;
}

@Injectable({ providedIn: 'root' })
export class CustomerService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiBaseUrl}/customers`;

  findAll(page: number, size: number, filter: CustomerFilter = {}): Observable<PageResponse<Customer>> {
    let params = new HttpParams().set('page', page).set('size', size).set('sort', 'name,asc');

    if (filter.name) {
      params = params.set('name', filter.name);
    }
    if (filter.email) {
      params = params.set('email', filter.email);
    }
    if (filter.phone) {
      params = params.set('phone', filter.phone);
    }
    if (filter.address) {
      params = params.set('address', filter.address);
    }
    if (filter.registrationDateFrom) {
      params = params.set('registrationDateFrom', filter.registrationDateFrom);
    }
    if (filter.registrationDateTo) {
      params = params.set('registrationDateTo', filter.registrationDateTo);
    }

    return this.http.get<PageResponse<Customer>>(this.baseUrl, { params });
  }

  findById(id: number): Observable<Customer> {
    return this.http.get<Customer>(`${this.baseUrl}/${id}`);
  }

  create(request: CustomerRequest): Observable<Customer> {
    return this.http.post<Customer>(this.baseUrl, request);
  }

  update(id: number, request: CustomerRequest): Observable<Customer> {
    return this.http.put<Customer>(`${this.baseUrl}/${id}`, request);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
