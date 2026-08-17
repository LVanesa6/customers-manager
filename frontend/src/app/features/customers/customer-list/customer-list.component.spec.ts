import { Directive, Input, TemplateRef, ViewContainerRef, inject } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { HasRolesDirective } from 'keycloak-angular';
import { of } from 'rxjs';

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

    expect(customerServiceMock.findAll).toHaveBeenCalledWith(0, 10, { name: '' });
  });

  it('reloads with the new page index and size when the paginator emits an event', () => {
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;

    component.loadPage({ pageIndex: 2, pageSize: 25, length: 0 });

    expect(component.pageIndex()).toBe(2);
    expect(component.pageSize()).toBe(25);
    expect(customerServiceMock.findAll).toHaveBeenLastCalledWith(2, 25, { name: '' });
  });

  it('resets to the first page when filters are applied', () => {
    const fixture = TestBed.createComponent(CustomerListComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance;

    component.loadPage({ pageIndex: 3, pageSize: 10, length: 0 });
    component.filterForm.controls.name.setValue('Gomez');
    component.applyFilters();

    expect(component.pageIndex()).toBe(0);
    expect(customerServiceMock.findAll).toHaveBeenLastCalledWith(0, 10, { name: 'Gomez' });
  });
});
