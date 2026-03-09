import { Component, OnInit, OnDestroy, inject, signal, HostListener } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { TangoBoardComponent } from './tango-board/tango-board.component';
import { TangoGameService } from './tango-game.service';
import { PuzzleService } from '../../core/services/puzzle.service';
import { GameHeaderService, DayBarItem } from '../../core/services/game-header.service';

interface WeekDay {
  index: number;
  name: string;
  letter: string;
  slug: string;
}

interface SavedResult {
  time: number;
  date: string;
  board?: number[][];
}

interface SavedProgress {
  board: number[][];
  timerSeconds: number;
  date: string;
}

const DAY_SLUGS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

@Component({
  selector: 'app-tango',
  standalone: true,
  imports: [TangoBoardComponent],
  providers: [TangoGameService],
  templateUrl: './tango.component.html',
  styleUrl: './tango.component.scss'
})
export class TangoComponent implements OnInit, OnDestroy {
  private puzzleService = inject(PuzzleService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private gameHeader = inject(GameHeaderService);
  game = inject(TangoGameService);

  private subs: Subscription[] = [];

  dayLabel = '';
  showModal = false;
  showInfo = false;
  selectedDay = signal(-1);
  todayIndex = -1;

  completedTime = signal(0);
  isCompleted = signal(false);
  completedPraise = signal('Bravo!');

  private readonly PRAISES = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];
  private pickPraise(): string {
    return this.PRAISES[Math.floor(Math.random() * this.PRAISES.length)];
  }

  showPause = false;
  checkResult = signal<'correct' | 'error' | null>(null);
  private checkTimeout: ReturnType<typeof setTimeout> | null = null;

  weekDays: WeekDay[] = [
    { index: 0, name: 'E Hënë', letter: 'H', slug: 'monday' },
    { index: 1, name: 'E Martë', letter: 'M', slug: 'tuesday' },
    { index: 2, name: 'E Mërkurë', letter: 'M', slug: 'wednesday' },
    { index: 3, name: 'E Enjte', letter: 'E', slug: 'thursday' },
    { index: 4, name: 'E Premte', letter: 'P', slug: 'friday' },
    { index: 5, name: 'E Shtunë', letter: 'Sh', slug: 'saturday' },
    { index: 6, name: 'E Diel', letter: 'D', slug: 'sunday' },
  ];

  ngOnInit(): void {
    this.todayIndex = this.getTodayIndex();
    this.gameHeader.enterGame();
    this.gameHeader.gameColor.set('#F97316');

    this.subs.push(
      this.gameHeader.infoClicked$.subscribe(() => this.openInfo()),
      this.gameHeader.daySelected$.subscribe(idx => this.navigateToDay(idx)),
    );

    this.subs.push(this.route.paramMap.subscribe(params => {
      const daySlug = params.get('day');

      if (!daySlug) {
        this.router.navigate(['/games/tango', DAY_SLUGS[this.todayIndex]], { replaceUrl: true });
        return;
      }

      const dayIndex = DAY_SLUGS.indexOf(daySlug.toLowerCase());

      if (dayIndex === -1 || dayIndex > this.todayIndex) {
        this.router.navigate(['/games/tango', DAY_SLUGS[this.todayIndex]], { replaceUrl: true });
        return;
      }

      this.loadPuzzle(dayIndex);
    }));
  }

  ngOnDestroy(): void {
    this.saveProgress();
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
  }

  private getTodayIndex(): number {
    const jsDay = new Date().getDay();
    return jsDay === 0 ? 6 : jsDay - 1;
  }

  private getWeekKey(): string {
    const now = new Date();
    const monday = new Date(now);
    const day = now.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    monday.setDate(now.getDate() + diff);
    return `${monday.getFullYear()}-${String(monday.getMonth() + 1).padStart(2, '0')}-${String(monday.getDate()).padStart(2, '0')}`;
  }

  private storageKey(dayIndex: number): string {
    return `tango_${this.getWeekKey()}_${dayIndex}`;
  }

  private progressKey(dayIndex: number): string {
    return `tango_progress_${this.getWeekKey()}_${dayIndex}`;
  }

  private getSavedResult(dayIndex: number): SavedResult | null {
    try {
      const raw = localStorage.getItem(this.storageKey(dayIndex));
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  private saveResult(dayIndex: number, time: number, board: number[][]): void {
    const result: SavedResult = { time, date: new Date().toISOString(), board };
    localStorage.setItem(this.storageKey(dayIndex), JSON.stringify(result));
  }

  isDayCompleted(dayIndex: number): boolean {
    return this.getSavedResult(dayIndex) !== null;
  }

  private getSavedProgress(dayIndex: number): SavedProgress | null {
    try {
      const raw = localStorage.getItem(this.progressKey(dayIndex));
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  private saveProgress(): void {
    const dayIndex = this.selectedDay();
    if (dayIndex < 0) return;
    const snapshot = this.game.getProgressSnapshot();
    if (!snapshot) return;
    const progress: SavedProgress = {
      board: snapshot.board,
      timerSeconds: snapshot.timerSeconds,
      date: new Date().toISOString(),
    };
    localStorage.setItem(this.progressKey(dayIndex), JSON.stringify(progress));
  }

  private clearProgress(dayIndex: number): void {
    localStorage.removeItem(this.progressKey(dayIndex));
  }

  private loadPuzzle(dayIndex: number): void {
    this.saveProgress(); // save current day progress before switching
    this.selectedDay.set(dayIndex);
    this.showModal = false;
    this.showPause = false;
    this.game.destroy();

    const saved = this.getSavedResult(dayIndex);

    this.puzzleService.getTangoByDay(dayIndex).subscribe(puzzle => {
      this.dayLabel = puzzle.dayName;
      this.game.initPuzzle(puzzle);

      if (saved) {
        this.clearProgress(dayIndex);
        this.isCompleted.set(true);
        this.completedTime.set(saved.time);
        this.completedPraise.set(this.pickPraise());
        this.game.destroy();
        this.game.timerSeconds.set(saved.time);
        if (saved.board && saved.board.length > 0) {
          this.game.restoreCompleted(saved.board);
        }
      } else {
        const progress = this.getSavedProgress(dayIndex);
        if (progress && progress.board.length > 0) {
          this.game.restorePaused(progress.board, progress.timerSeconds);
          this.isCompleted.set(false);
          this.completedTime.set(0);
          this.showPause = true;
        } else {
          this.isCompleted.set(false);
          this.completedTime.set(0);
        }
      }

      this.updateDayBar();
    });
  }

  navigateToDay(dayIndex: number): void {
    this.router.navigate(['/games/tango', DAY_SLUGS[dayIndex]]);
  }

  isDayAccessible(dayIndex: number): boolean {
    return dayIndex <= this.todayIndex;
  }

  onWin(): void {
    const dayIndex = this.selectedDay();
    const time = this.game.timerSeconds();
    const winningBoard = this.game.board().map(row => [...row]);
    this.saveResult(dayIndex, time, winningBoard);
    this.isCompleted.set(true);
    this.completedTime.set(time);
    this.completedPraise.set(this.pickPraise());
    this.clearProgress(dayIndex);
  }

  onUndo(): void { this.game.undo(); }

  onCheck(): void {
    if (this.checkTimeout) { clearTimeout(this.checkTimeout); this.checkTimeout = null; }
    const isCorrect = this.game.checkCorrect();
    this.checkResult.set(isCorrect ? 'correct' : 'error');
    this.checkTimeout = setTimeout(() => {
      this.checkResult.set(null);
      this.checkTimeout = null;
    }, 3000);
  }

  onHint(): void {
    this.game.hint();
  }

  @HostListener('document:visibilitychange')
  onVisibilityChange(): void {
    if (document.hidden) {
      this.pauseGame();
    }
  }

  @HostListener('window:beforeunload')
  onBeforeUnload(): void {
    this.saveProgress();
  }

  pauseGame(): void {
    if (this.game.gameWon()) return;
    this.game.pauseTimer();
    this.saveProgress();
    this.showPause = true;
  }

  resumeGame(): void {
    this.showPause = false;
    this.game.resumeTimer();
  }

  getTodayDateLabel(): string {
    const days = ['E Diel', 'E Hënë', 'E Martë', 'E Mërkurë', 'E Enjte', 'E Premte', 'E Shtunë'];
    const months = ['Janar', 'Shkurt', 'Mars', 'Prill', 'Maj', 'Qershor', 'Korrik', 'Gusht', 'Shtator', 'Tetor', 'Nëntor', 'Dhjetor'];
    const now = new Date();
    const day = days[now.getDay()];
    const month = months[now.getMonth()];
    const date = now.getDate();
    return `${day}, ${date} ${month}`;
  }

  closeModal(): void { this.showModal = false; }
  openInfo(): void { this.showInfo = true; }
  closeInfo(): void { this.showInfo = false; }

  onClear(): void {
    if (this.isCompleted()) return;
    const dayIndex = this.selectedDay();
    this.clearProgress(dayIndex);
    this.showModal = false;
    this.game.reset();
  }

  private updateDayBar(): void {
    const items: DayBarItem[] = this.weekDays.map(d => ({
      index: d.index,
      letter: d.letter,
      name: d.name,
      accessible: d.index <= this.todayIndex,
      completed: this.isDayCompleted(d.index),
      isToday: d.index === this.todayIndex,
    }));
    this.gameHeader.setDayBar(items, this.selectedDay());
  }

  hasPreviousDay(): boolean {
    const current = this.selectedDay();
    if (current <= 0) return false;
    for (let i = current - 1; i >= 0; i--) {
      if (this.isDayAccessible(i) && !this.isDayCompleted(i)) return true;
    }
    return current > 0;
  }

  playPreviousDay(): void {
    const current = this.selectedDay();
    this.showModal = false;
    for (let i = current - 1; i >= 0; i--) {
      if (this.isDayAccessible(i) && !this.isDayCompleted(i)) {
        this.navigateToDay(i);
        return;
      }
    }
    if (current > 0) {
      this.navigateToDay(current - 1);
    }
  }
}
