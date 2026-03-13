import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

interface SubscriptionResponse {
  success: boolean;
  message: string;
}

@Injectable({ providedIn: 'root' })
export class SubscriptionService {
  private http = inject(HttpClient);

  subscribe(email: string): Observable<SubscriptionResponse> {
    return this.http.post<SubscriptionResponse>('/api/subscription/subscribe', { email });
  }
}
