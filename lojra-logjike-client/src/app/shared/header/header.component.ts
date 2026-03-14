import { Component, inject, ElementRef, ViewChild } from '@angular/core';
import { RouterLink } from '@angular/router';
import { GameHeaderService } from '../../core/services/game-header.service';
// import { SettingsModalComponent } from '../settings-modal/settings-modal.component'; // TODO: Uncomment when email subscription is needed

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss'
})
export class HeaderComponent {
  gameHeader = inject(GameHeaderService);

  showDayModal = false;
  showSettings = false;
  modalTop = 0;
  modalRight = 0;

  @ViewChild('dayBtn') dayBtnRef!: ElementRef<HTMLButtonElement>;

  onInfo(): void {
    this.gameHeader.triggerInfo();
  }

  onSettings(): void {
    this.showSettings = true;
  }

  closeSettings(): void {
    this.showSettings = false;
  }

  toggleDayModal(): void {
    if (!this.showDayModal && this.dayBtnRef) {
      const rect = this.dayBtnRef.nativeElement.getBoundingClientRect();
      this.modalTop = rect.bottom + 8;
      this.modalRight = window.innerWidth - rect.right;
    }
    this.showDayModal = !this.showDayModal;
  }

  selectDay(index: number): void {
    this.gameHeader.selectDay(index);
    this.showDayModal = false;
  }
}
