import { Component, OnInit, OnDestroy, inject, signal } from '@angular/core';
import { Subscription } from 'rxjs';
import { Wordle7BoardComponent } from './wordle7-board/wordle7-board.component';
import { Wordle7GameService } from './wordle7-game.service';
import { PuzzleService } from '../../core/services/puzzle.service';
import { GameHeaderService } from '../../core/services/game-header.service';

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
  completedSwaps = signal(0);
  isCompleted = signal(false);
  completedPraise = signal('Bravo!');
  completedIcon = signal('icons/rewards/rocket.svg');

  // Puzzle tracking
  puzzleNumber = signal(1);
  isLoading = signal(false);
  loadingPercent = signal(0);
  private lastWords: string[] = [];
  private loadingInterval: ReturnType<typeof setInterval> | null = null;

  // New puzzle cooldown (10 seconds)
  newPuzzleCooldown = signal(0);
  private cooldownTimer: ReturnType<typeof setInterval> | null = null;

  private readonly ICONS = ['icons/rewards/rocket.svg', 'icons/rewards/fire.svg', 'icons/rewards/trophy.svg'];
  private readonly PRAISES = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];
  private pickPraise(): string {
    return this.PRAISES[Math.floor(Math.random() * this.PRAISES.length)];
  }
  private pickIcon(): string {
    return this.ICONS[Math.floor(Math.random() * this.ICONS.length)];
  }

  ngOnInit(): void {
    this.gameHeader.enterGame();
    this.gameHeader.gameColor.set('#22C55E');
    this.gameHeader.dayBarVisible.set(false);

    this.subs.push(
      this.gameHeader.infoClicked$.subscribe(() => this.openInfo()),
    );

    // Try to restore a saved game first
    const saved = Wordle7GameService.loadSavedState();
    if (saved) {
      this.lastWords = saved.puzzle.words.map(w => w.word);
      this.game.restorePuzzle(saved.puzzle, saved.grid, saved.swapCount, saved.hintCount, saved.totalSwapCount);
    } else {
      this.loadRandomPuzzle();
    }
  }

  ngOnDestroy(): void {
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
    this.clearCooldown();
    this.stopLoadingProgress();
  }

  private loadRandomPuzzle(): void {
    this.isLoading.set(true);
    this.isCompleted.set(false);
    this.completedSwaps.set(0);
    this.game.destroy();
    Wordle7GameService.clearSavedState();

    this.startLoadingProgress();

    this.puzzleService.getRandomWordle7(this.lastWords).subscribe(puzzle => {
      this.lastWords = puzzle.words.map(w => w.word);
      this.loadingPercent.set(100);
      this.stopLoadingProgress();

      // Brief pause at 100% so user sees it complete
      setTimeout(() => {
        this.game.initPuzzle(puzzle);
        this.isLoading.set(false);
        this.loadingPercent.set(0);
      }, 300);
    });
  }

  private startLoadingProgress(): void {
    this.stopLoadingProgress();
    this.loadingPercent.set(0);
    let current = 0;
    this.loadingInterval = setInterval(() => {
      // Simulate progress: fast at start, slows down approaching 90%
      const remaining = 90 - current;
      const increment = Math.max(0.5, remaining * 0.08);
      current = Math.min(90, current + increment);
      this.loadingPercent.set(Math.round(current));
    }, 100);
  }

  private stopLoadingProgress(): void {
    if (this.loadingInterval) {
      clearInterval(this.loadingInterval);
      this.loadingInterval = null;
    }
  }

  playAnother(): void {
    Wordle7GameService.clearSavedState();
    this.puzzleNumber.update(n => n + 1);
    this.loadRandomPuzzle();
    this.startCooldown();
  }

  private startCooldown(): void {
    this.clearCooldown();
    this.newPuzzleCooldown.set(10);
    this.cooldownTimer = setInterval(() => {
      const remaining = this.newPuzzleCooldown() - 1;
      if (remaining <= 0) {
        this.newPuzzleCooldown.set(0);
        this.clearCooldown();
      } else {
        this.newPuzzleCooldown.set(remaining);
      }
    }, 1000);
  }

  private clearCooldown(): void {
    if (this.cooldownTimer) {
      clearInterval(this.cooldownTimer);
      this.cooldownTimer = null;
    }
  }

  onWin(): void {
    const swaps = this.game.swapCount();
    this.isCompleted.set(true);
    this.completedSwaps.set(swaps);
    this.completedPraise.set(this.pickPraise());
    this.completedIcon.set(this.pickIcon());
  }

  onHint(): void {
    this.game.hint();
  }

  onSolveWord(): void {
    this.game.solveWord();
  }

  openInfo(): void { this.showInfo = true; }
  closeInfo(): void { this.showInfo = false; }
}
