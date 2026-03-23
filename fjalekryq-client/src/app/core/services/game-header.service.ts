import { Injectable, signal, computed } from '@angular/core';
import { Subject } from 'rxjs';

export interface DayBarItem {
  index: number;
  letter: string;
  name: string;
  accessible: boolean;
  completed: boolean;
  isToday: boolean;
}

@Injectable({ providedIn: 'root' })
export class GameHeaderService {
  /** Whether the current page is a game page (shows ? and ⚙ in header) */
  isGamePage = signal(false);

  /** The active game's theme color */
  readonly gameColor = signal('#6B21A8');

  /** Day bar data (provided by game components) */
  readonly dayBarItems = signal<DayBarItem[]>([]);
  readonly dayBarVisible = signal(false);
  readonly dayBarSelectedIndex = signal(-1);

  /** The name of the currently selected day (for the day button label) */
  readonly selectedDayName = computed(() => {
    const items = this.dayBarItems();
    const idx = this.dayBarSelectedIndex();
    const item = items.find(i => i.index === idx);
    return item ? item.name : '';
  });

  /** Emits when the ? (info) button in the header is clicked */
  readonly infoClicked$ = new Subject<void>();

  /** Emits when the ⚙ (settings) button in the header is clicked */
  readonly settingsClicked$ = new Subject<void>();

  /** Emits when a day chip in the header is clicked (header → game) */
  readonly daySelected$ = new Subject<number>();

  /** Called by game components on init */
  enterGame(): void {
    this.isGamePage.set(true);
  }

  /** Called by game components on destroy */
  leaveGame(): void {
    this.isGamePage.set(false);
    this.dayBarVisible.set(false);
    this.dayBarItems.set([]);
    this.dayBarSelectedIndex.set(-1);
    this.gameColor.set('#6B21A8');
  }

  /** Called by game components to provide day bar data */
  setDayBar(items: DayBarItem[], selectedIndex: number): void {
    this.dayBarItems.set(items);
    this.dayBarSelectedIndex.set(selectedIndex);
    this.dayBarVisible.set(true);
  }

  /** Update which day is selected */
  updateSelectedDay(index: number): void {
    this.dayBarSelectedIndex.set(index);
  }

  /** Called by header when a day chip is clicked */
  selectDay(index: number): void {
    this.daySelected$.next(index);
  }

  /** Called by header when ? is clicked */
  triggerInfo(): void {
    this.infoClicked$.next();
  }

  /** Called by header when ⚙ is clicked */
  triggerSettings(): void {
    this.settingsClicked$.next();
  }
}
