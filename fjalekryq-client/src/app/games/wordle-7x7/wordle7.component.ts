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
  private lastHash: string | undefined;

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

    this.loadRandomPuzzle();
  }

  ngOnDestroy(): void {
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
    this.clearCooldown();
  }

  private loadRandomPuzzle(): void {
    this.isLoading.set(true);
    this.isCompleted.set(false);
    this.completedSwaps.set(0);
    this.game.destroy();

    this.puzzleService.getRandomWordle7(this.lastHash).subscribe(puzzle => {
      this.lastHash = puzzle.hash;
      this.game.initPuzzle(puzzle);
      this.isLoading.set(false);
    });
  }

  playAnother(): void {
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

  openInfo(): void { this.showInfo = true; }
  closeInfo(): void { this.showInfo = false; }
}
