import { Component, OnInit, OnDestroy, inject, signal, HostListener } from '@angular/core';
import { Subscription } from 'rxjs';
import { Wordle7BoardComponent } from './wordle7-board/wordle7-board.component';
import { Wordle7GameService } from './wordle7-game.service';
import { PuzzleService } from '../../core/services/puzzle.service';
import { GameHeaderService } from '../../core/services/game-header.service';

interface SavedProgress {
  grid: string[][];
  timerSeconds: number;
  swapCount: number;
  date: string;
}

@Component({
  selector: 'app-wordle7',
  standalone: true,
  imports: [Wordle7BoardComponent],
  providers: [Wordle7GameService],
  templateUrl: './wordle7.component.html',
  styleUrl: './wordle7.component.scss'
})
export class Wordle7Component implements OnInit, OnDestroy {
  private puzzleService = inject(PuzzleService);
  private gameHeader = inject(GameHeaderService);
  game = inject(Wordle7GameService);

  private subs: Subscription[] = [];

  showInfo = false;

  // Completion state
  completedTime = signal(0);
  completedSwaps = signal(0);
  isCompleted = signal(false);
  completedPraise = signal('Bravo!');
  completedIcon = signal('icons/rewards/rocket.svg');

  // Puzzle counter
  puzzleNumber = signal(1);
  isLoading = signal(false);

  private readonly ICONS = ['icons/rewards/rocket.svg', 'icons/rewards/fire.svg', 'icons/rewards/trophy.svg'];
  private readonly PRAISES = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];
  private pickPraise(): string {
    return this.PRAISES[Math.floor(Math.random() * this.PRAISES.length)];
  }
  private pickIcon(): string {
    return this.ICONS[Math.floor(Math.random() * this.ICONS.length)];
  }

  // Pause state
  showPause = false;

  ngOnInit(): void {
    this.gameHeader.enterGame();
    this.gameHeader.gameColor.set('#22C55E');
    // Hide the day bar since we no longer use day-based navigation
    this.gameHeader.dayBarVisible.set(false);

    this.subs.push(
      this.gameHeader.infoClicked$.subscribe(() => this.openInfo()),
    );

    this.loadRandomPuzzle();
  }

  ngOnDestroy(): void {
    this.saveProgress();
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
  }

  private get progressKey(): string {
    return `wordle7_progress_current`;
  }

  private getSavedProgress(): SavedProgress | null {
    try {
      const raw = localStorage.getItem(this.progressKey);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  private saveProgress(): void {
    const snapshot = this.game.getProgressSnapshot();
    if (!snapshot) return;
    const progress: SavedProgress = {
      grid: snapshot.grid,
      timerSeconds: snapshot.timerSeconds,
      swapCount: snapshot.swapCount,
      date: new Date().toISOString(),
    };
    localStorage.setItem(this.progressKey, JSON.stringify(progress));
  }

  private clearProgress(): void {
    localStorage.removeItem(this.progressKey);
  }

  private loadRandomPuzzle(): void {
    this.isLoading.set(true);
    this.isCompleted.set(false);
    this.completedTime.set(0);
    this.completedSwaps.set(0);
    this.showPause = false;
    this.game.destroy();

    this.puzzleService.getRandomWordle7().subscribe(puzzle => {
      this.game.initPuzzle(puzzle);
      this.isLoading.set(false);
    });
  }

  playAnother(): void {
    this.clearProgress();
    this.puzzleNumber.update(n => n + 1);
    this.loadRandomPuzzle();
  }

  onWin(): void {
    const time = this.game.timerSeconds();
    const swaps = this.game.swapCount();
    this.isCompleted.set(true);
    this.completedTime.set(time);
    this.completedSwaps.set(swaps);
    this.completedPraise.set(this.pickPraise());
    this.completedIcon.set(this.pickIcon());
    this.clearProgress();
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
    return `${days[now.getDay()]}, ${now.getDate()} ${months[now.getMonth()]}`;
  }

  onReset(): void {
    if (this.isCompleted()) return;
    this.clearProgress();
    this.game.resetPuzzle();
  }

  onHint(): void {
    this.game.hint();
  }

  openInfo(): void { this.showInfo = true; }
  closeInfo(): void { this.showInfo = false; }
}
