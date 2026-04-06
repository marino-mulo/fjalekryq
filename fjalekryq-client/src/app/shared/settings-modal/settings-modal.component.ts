import { Component, input, output, effect, signal } from '@angular/core';

@Component({
  selector: 'app-settings-modal',
  standalone: true,
  imports: [],
  templateUrl: './settings-modal.component.html',
  styleUrl: './settings-modal.component.scss'
})
export class SettingsModalComponent {
  isOpen = input(false);
  closed = output<void>();

  musicEnabled             = signal(true);
  soundEnabled             = signal(true);
  notificationsEnabled     = signal(true);
  emailNotificationsEnabled = signal(true);

  constructor() {
    effect(() => {
      if (this.isOpen()) this.loadSavedState();
    });
  }

  private loadSavedState(): void {
    const music = localStorage.getItem('fjalekryq_music');
    this.musicEnabled.set(music === null ? true : music === 'true');

    const sound = localStorage.getItem('fjalekryq_sound');
    this.soundEnabled.set(sound === null ? true : sound === 'true');

    const notif = localStorage.getItem('fjalekryq_notif');
    this.notificationsEnabled.set(notif === null ? true : notif === 'true');

    const emailNotif = localStorage.getItem('fjalekryq_email_notif');
    this.emailNotificationsEnabled.set(emailNotif === null ? true : emailNotif === 'true');
  }

  toggleMusic(): void {
    const next = !this.musicEnabled();
    this.musicEnabled.set(next);
    localStorage.setItem('fjalekryq_music', String(next));
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

  toggleEmailNotifications(): void {
    const next = !this.emailNotificationsEnabled();
    this.emailNotificationsEnabled.set(next);
    localStorage.setItem('fjalekryq_email_notif', String(next));
  }

  close(): void {
    this.closed.emit();
  }
}
