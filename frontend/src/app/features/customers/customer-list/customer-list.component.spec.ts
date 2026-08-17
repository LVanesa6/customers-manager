import { Directive, Input, TemplateRef, ViewContainerRef, inject } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { HasRolesDirective } from 'keycloak-angular';
import { of, throwError } from 'rxjs';

import { CustomerListComponent } from './customer-list.component';
import { CustomerService } from '../customer.service';

/**
 * keycloak-angular's real HasRolesDirective requires a live Keycloak instance.
 * For this spec we only care about pagination/filtering logic, so it is swapped
 * for a stub that always renders its content, keeping the test hermetic.
 */
@Directive({ selector: '[kaHasRoles]', standalone: true })
class StubHasRolesDirective {
  private readonly templateRef = inject(TemplateRef);
  private readonly viewContainer = inject(ViewContainerRef);

  @Input('kaHasRoles') roles: string[] = [];
  @Input('kaHasRolesCheckRealm') checkRealm = false;

  ngOnInit(): void {
    this.viewContainer.createEmbeddedView(this.templateRef);
  }
}

describe('CustomerListComponent', () => {
  let customerServiceMock: Partial<jest.Mocked<CustomerService>>;

  const emptyPage = { content: [], page: 0, size: 10, totalElements: 0, totalPages: 0, last: true };
  const emptyFilter = { name: '', email: '', phone: '', address: '', registrationDateFrom: null, registrationDateTo: null };

  beforeEach(() => {
    customerServiceMock = { findAll: jest.fn().mockReturnValue(of(emptyPage)) };

    TestBed.configureTestingModule({
      imports: [CustomerListComponent],
      providers: [{ provide: CustomerService, useValue: customerServiceMock }, provideRouter([]), provideNoopAnimations()],
    });

    TestBed.overrideComponent(CustomerListComponent, {
      remove: { imports: [HasRolesDirective] },
      add: { imports: [StubHasRolesDirective] },
    });
  });

  it('loads the first page of customers on init', () => {
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();

    expect(customerServiceMock.findAll).toHaveBeenCalledWith(0, 10, emptyFilter);
  });

  it('reloads with the new page index when the paginator emits a page change', () => {
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;

    component.onPageChange(2);

    expect(component.pageIndex()).toBe(2);
    expect(customerServiceMock.findAll).toHaveBeenLastCalledWith(2, 10, emptyFilter);
  });

  it('resets to the first page when filters are applied', () => {
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;

    component.onPageChange(3);
    component.filterForm.controls.name.setValue('Gomez');
    component.applyFilters();

    expect(component.pageIndex()).toBe(0);
    expect(customerServiceMock.findAll).toHaveBeenLastCalledWith(0, 10, { ...emptyFilter, name: 'Gomez' });
  });

  it('sets loadError to true when loading fails, instead of leaving a silent empty table', () => {
    customerServiceMock.findAll = jest.fn().mockReturnValue(throwError(() => new Error('network down')));

    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;

    expect(component.loadError()).toBe(true);
    expect(component.loading()).toBe(false);
  });

  it('clears loadError and reloads when retrying after a failed load', () => {
    customerServiceMock.findAll = jest.fn().mockReturnValue(throwError(() => new Error('network down')));
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;
    expect(component.loadError()).toBe(true);

    customerServiceMock.findAll = jest.fn().mockReturnValue(of(emptyPage));
    component.loadPage();

    expect(component.loadError()).toBe(false);
  });
});
