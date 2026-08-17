import { HttpClient } from '@angular/common/http';
import { Injectable, inject, signal } from '@angular/core';

import { environment } from '../../../environments/environment';

interface ActuatorInfo {
  environment?: string;
  descripcion?: string;
}

@Injectable({ providedIn: 'root' })
export class EnvironmentInfoService {
  private readonly http = inject(HttpClient);

  readonly label = signal<string | null>(null);
  readonly description = signal<string | null>(null);

  constructor() {
    this.http.get<ActuatorInfo>(`${environment.actuatorBaseUrl}/info`).subscribe({
      next: (info) => {
        this.label.set(info.environment ?? null);
        this.description.set(info.descripcion ?? null);
      },
      error: () => {
        this.label.set(null);
      },
    });
  }
}
