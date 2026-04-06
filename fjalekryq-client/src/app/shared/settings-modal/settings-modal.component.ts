import { Component, input, output, inject, effect, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { SubscriptionService } from '../../core/services/subscription.service';

@Component({
  selector: 'app-settings-modal',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './settings-modal.component.html',
  styleUrl: './settings-modal.component.scss'
})
export class SettingsModalComponent {
  isOpen = input(false);
  closed = output<void>();

  private subscriptionService = inject(SubscriptionService);

  email = '';
  subscribed = false;
  statusMessage = '';
  statusType: 'success' | 'error' | '' = '';
  loading = false;

  soundEnabled = signal(true);
  notificationsEnabled = signal(true);

  private emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  constructor() {
    effect(() => {
      if (this.isOpen()) {
        this.loadSavedState();
      }
    });
  }

  private loadSavedState(): void {
    this.statusMessage = '';
    this.statusType = '';

    const saved = localStorage.getItem('ll_subscribed_email');
    if (saved) {
      this.email = saved;
      this.subscribed = true;
    }

    const sound = localStorage.getItem('fjalekryq_sound');
    this.soundEnabled.set(sound === null ? true : sound === 'true');

    const notif = localStorage.getItem('fjalekryq_notif');
    this.notificationsEnabled.set(notif === null ? true : notif === 'true');
  }

  toggleSound(): void {
    const next = !this.soundEnabled();
    this.soundEnabled.set(next);
    localStorage.setItem('fjalekryq_sound', String(next));
  }

  toggleNotifications(): void {
    const next = !this.notificationsEnabled();
    this.notificationsEnabled.set(next);
    localStorage.setItem('fjalekryq_notif', String(next));
  }

  close(): void {
    this.closed.emit();
  }

  onEmailChange(): void {
    this.email = this.email.toLowerCase();
    this.statusMessage = '';
    this.statusType = '';
    this.subscribed = false;
  }

  get isValidEmail(): boolean {
    return this.emailRegex.test(this.email.trim());
  }

  subscribe(): void {
    const trimmed = this.email.trim().toLowerCase();
    if (!trimmed || this.loading) return;

    if (!this.isValidEmail) {
      this.statusMessage = 'Ju lutem shkruani një email të vlefshëm (p.sh. emri@domain.com).';
      this.statusType = 'error';
      return;
    }

    this.email = trimmed;
    this.loading = true;
    this.statusMessage = '';

    this.subscriptionService.subscribe(trimmed).subscribe({
      next: (res) => {
        this.loading = false;
        this.statusMessage = res.message;
        this.statusType = res.success ? 'success' : 'error';
        if (res.success) {
          this.subscribed = true;
          localStorage.setItem('ll_subscribed_email', trimmed);
        }
      },
      error: (err) => {
        this.loading = false;
        const msg = err?.error?.message;
        this.statusMessage = msg || 'Ndodhi një gabim. Provoni përsëri.';
        this.statusType = 'error';
      }
    });
  }
}
