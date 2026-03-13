import { Component, inject, ElementRef, ViewChild } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { ViewportScroller } from '@angular/common';
import { GameHeaderService } from '../../core/services/game-header.service';
import { SettingsModalComponent } from '../settings-modal/settings-modal.component';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [RouterLink, SettingsModalComponent],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss'
})
export class HeaderComponent {
  private router = inject(Router);
  private scroller = inject(ViewportScroller);
  gameHeader = inject(GameHeaderService);

  showDayModal = false;
  showSettings = false;
  modalTop = 0;
  modalRight = 0;

  @ViewChild('dayBtn') dayBtnRef!: ElementRef<HTMLButtonElement>;

  scrollTo(fragment: string) {
    if (this.router.url === '/' || this.router.url.startsWith('/#')) {
      this.scroller.scrollToAnchor(fragment);
    } else {
      this.router.navigate(['/'], { fragment });
    }
  }

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
