import { Component, computed, input, output } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

type PageToken = number | '...';

@Component({
  selector: 'app-pagination',
  standalone: true,
  imports: [MatIconModule],
  templateUrl: './pagination.component.html',
  styleUrl: './pagination.component.scss',
})
export class PaginationComponent {
  readonly pageIndex = input.required<number>();
  readonly pageSize = input.required<number>();
  readonly totalElements = input.required<number>();

  readonly pageChange = output<number>();

  readonly totalPages = computed(() => Math.max(1, Math.ceil(this.totalElements() / this.pageSize())));
  readonly currentPage = computed(() => this.pageIndex() + 1);

  readonly pages = computed<PageToken[]>(() => {
    const total = this.totalPages();
    const current = this.currentPage();
    const delta = 2;

    const tokens: PageToken[] = [1];
    const rangeStart = Math.max(2, current - delta);
    const rangeEnd = Math.min(total - 1, current + delta);

    if (rangeStart > 2) {
      tokens.push('...');
    }
    for (let page = rangeStart; page <= rangeEnd; page++) {
      tokens.push(page);
    }
    if (rangeEnd < total - 1) {
      tokens.push('...');
    }
    if (total > 1) {
      tokens.push(total);
    }

    return tokens;
  });

  goTo(page: number): void {
    if (page < 1 || page > this.totalPages() || page === this.currentPage()) {
      return;
    }
    this.pageChange.emit(page - 1);
  }

  previous(): void {
    this.goTo(this.currentPage() - 1);
  }

  next(): void {
    this.goTo(this.currentPage() + 1);
  }
}
