import { Component, OnInit, OnDestroy, inject, signal, computed, Output, EventEmitter, effect } from '@angular/core';
import { Subscription } from 'rxjs';
import { retry } from 'rxjs/operators';
import { NgClass } from '@angular/common';
import { Wordle7BoardComponent } from './wordle7-board/wordle7-board.component';
import { Wordle7GameService } from './wordle7-game.service';
import { PuzzleService } from '../../core/services/puzzle.service';
import { GameHeaderService } from '../../core/services/game-header.service';
import { CoinService, HINT_COST, SOLVE_COST } from '../../core/services/coin.service';
import { SettingsModalComponent } from '../../shared/settings-modal/settings-modal.component';

const LEVEL_KEY          = 'fjalekryq_level';         // player's max progress
const PLAYING_LEVEL_KEY  = 'fjalekryq_playing_level'; // level currently being played
const TUTORIAL_KEY       = 'fjalekryq_tutorial_done';
const FORCE_TUTORIAL_KEY = 'fjalekryq_force_tutorial';
const STARS_KEY_PREFIX   = 'fjalekryq_stars_';

// Coins earned per level clear by difficulty (first clear only)
const LEVEL_DIFFICULTY: Record<number, string> = {
  1: 'easy', 2: 'easy', 3: 'easy',
  4: 'medium', 5: 'medium', 6: 'medium',
  7: 'hard', 8: 'hard', 9: 'hard',
  10: 'expert',
};
const DIFFICULTY_COINS: Record<string, number> = {
  easy: 20, medium: 35, hard: 50, expert: 80,
};

// 7×7 tutorial: MALI (vertical col 3), BORA (horizontal row 1), DETI (horizontal row 3)
// Intersections: MALI∩BORA at A(1,3), MALI∩DETI at I(3,3)
const TUTORIAL_PUZZLE = {
  gridSize: 7,
  solution: [
    ['X', 'X', 'X', 'M', 'X', 'X', 'X'],
    ['B', 'O', 'R', 'A', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'L', 'X', 'X', 'X'],
    ['D', 'E', 'T', 'I', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
    ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ],
  words: [
    { word: 'MALI', row: 0, col: 3, direction: 'vertical'   as const },
    { word: 'BORA', row: 1, col: 0, direction: 'horizontal' as const },
    { word: 'DETI', row: 3, col: 0, direction: 'horizontal' as const },
  ],
  hash: 'tutorial_v1',
  swapLimit: 7,
};

// Fixed starting grid: B↔M swapped at (0,3)/(1,0), DETI row fully scrambled as IDET
const TUTORIAL_INITIAL_GRID = [
  ['X', 'X', 'X', 'B', 'X', 'X', 'X'],
  ['M', 'O', 'R', 'A', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'L', 'X', 'X', 'X'],
  ['I', 'D', 'E', 'T', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
  ['X', 'X', 'X', 'X', 'X', 'X', 'X'],
];

// tutorialPhase: 0=off, 1=swap modal, 2=interactive swap, 3=colors modal, 4=hint modal,
//               5=interactive hint, 6=moves modal, 7=solve modal, 8=interactive solve, 9=done banner
export type TutorialPhase = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;

const BG_LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split('');
const BG_COLORS  = ['gold', 'lime', 'grey'] as const;

interface BgTile {
  id: number; letter: string;
  x: number;  y: number;
  color: 'gold' | 'lime' | 'grey';
  delay: number;
}

@Component({
  selector: 'app-wordle7',
  standalone: true,
  imports: [Wordle7BoardComponent, NgClass, SettingsModalComponent],
  providers: [Wordle7GameService],
  templateUrl: './wordle7.component.html',
  styleUrl: './wordle7.component.scss'
})
export class Wordle7Component implements OnInit, OnDestroy {
  private puzzleService = inject(PuzzleService);
  private gameHeader    = inject(GameHeaderService);
  coinService           = inject(CoinService);
  game                  = inject(Wordle7GameService);

  readonly HINT_COST  = HINT_COST;
  readonly SOLVE_COST = SOLVE_COST;

  readonly canAffordHint  = computed(() => this.coinService.canAfford(HINT_COST));
  readonly canAffordSolve = computed(() => this.coinService.canAfford(SOLVE_COST));

  @Output() goBack = new EventEmitter<void>();

  private subs: Subscription[] = [];

  showInfo = false;

  // Tutorial
  isTutorial    = signal(false);
  tutorialPhase = signal<TutorialPhase>(0);
  tutorialHighlightCells = signal<{row: number; col: number}[]>([]);

  // Shop / settings in puzzle
  showShop     = signal(false);
  showSettings = signal(false);

  // Completion
  isCompleted      = signal(false);
  completedPraise  = signal('Bravo!');
  completedIcon    = signal('icons/rewards/rocket.svg');
  completedStars   = signal(0);
  coinsEarned      = signal(0);
  insufficientCoins  = signal<'hint' | 'solve' | null>(null);

  // Puzzle / loading
  isLoading      = signal(false);
  loadingPercent = signal(0);

  bgTiles = signal<BgTile[]>([]);
  puzzleIntroTrigger = signal(0);
  private bgSwapTimer: ReturnType<typeof setInterval> | null = null;

  private readonly ICONS   = ['icons/rewards/rocket.svg', 'icons/rewards/fire.svg', 'icons/rewards/trophy.svg'];
  private readonly PRAISES = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];
  private pickPraise() { return this.PRAISES[Math.floor(Math.random() * this.PRAISES.length)]; }
  private pickIcon()   { return this.ICONS[Math.floor(Math.random() * this.ICONS.length)]; }

  /** Stars based purely on moves remaining: 7+ = 3, 3-6 = 2, 1-2 = 1 */
  private computeStars(): number {
    const rem = this.game.swapsRemaining();
    if (rem >= 7) return 3;
    if (rem >= 3) return 2;
    return 1;
  }

  /** Live star preview shown in the header during play */
  readonly previewStars = computed(() => {
    const rem = this.game.swapsRemaining();
    if (rem >= 7) return 3;
    if (rem >= 3) return 2;
    return 1;
  });

  difficultyLabel    = '';
  difficultyCssClass = '';

  private readonly DIFF_LABELS: Record<string, string> = {
    easy: 'E lehtë', medium: 'Mesatare', hard: 'E vështirë', expert: 'Ekspert',
  };
  private readonly DIFF_CSS: Record<string, string> = {
    easy: 'diff-easy', medium: 'diff-medium', hard: 'diff-hard', expert: 'diff-expert',
  };

  constructor() {
    // Phase 2 → 3: advance when first swap happens
    effect(() => {
      if (this.isTutorial() && this.tutorialPhase() === 2 && this.game.totalSwapCount() > 0) {
        this.setTutorialPhase(3);
      }
    }, { allowSignalWrites: true });

    // Phase 5 → 6: advance when hint is used
    effect(() => {
      if (this.isTutorial() && this.tutorialPhase() === 5 && this.game.hintCount() > 0) {
        this.setTutorialPhase(6);
      }
    }, { allowSignalWrites: true });

    // Phase 8 → 9: advance when solve is used (cooldown starts)
    effect(() => {
      if (this.isTutorial() && this.tutorialPhase() === 8 && this.game.solveWordCooldown()) {
        this.setTutorialPhase(9);
      }
    }, { allowSignalWrites: true });
  }

  ngOnInit(): void {
    this.gameHeader.enterGame();
    this.gameHeader.gameColor.set('#22C55E');
    this.gameHeader.dayBarVisible.set(false);
    this.subs.push(this.gameHeader.infoClicked$.subscribe(() => this.openInfo()));

    // Set difficulty label from playing level
    const playingLevel = parseInt(localStorage.getItem(PLAYING_LEVEL_KEY) ?? localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    const diff = LEVEL_DIFFICULTY[playingLevel] ?? 'easy';
    this.difficultyLabel    = this.DIFF_LABELS[diff] ?? diff;
    this.difficultyCssClass = this.DIFF_CSS[diff] ?? 'diff-easy';

    const forceTutorial = localStorage.getItem(FORCE_TUTORIAL_KEY) === 'true';
    if (forceTutorial) localStorage.removeItem(FORCE_TUTORIAL_KEY);

    const level        = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    const tutorialDone = localStorage.getItem(TUTORIAL_KEY) === 'true';

    if ((level === 1 && !tutorialDone) || forceTutorial) {
      this.isTutorial.set(true);
      this.game.setTutorialMode(true);
      this.game.restorePuzzle(TUTORIAL_PUZZLE, TUTORIAL_INITIAL_GRID.map(r => [...r]), 0, 0, 0);
      this.setTutorialPhase(1);
      setTimeout(() => this.puzzleIntroTrigger.update(v => v + 1), 50);
    } else {
      const playingLevel = parseInt(localStorage.getItem(PLAYING_LEVEL_KEY) ?? localStorage.getItem(LEVEL_KEY) ?? '1', 10);
      const saved = Wordle7GameService.loadSavedState();
      if (saved && saved.puzzle.hash !== 'tutorial_v1' && (saved as any).level === playingLevel) {
        this.game.restorePuzzle(saved.puzzle, saved.grid, saved.swapCount, saved.hintCount, saved.totalSwapCount);
        setTimeout(() => this.puzzleIntroTrigger.update(v => v + 1), 50);
      } else {
        this.loadRandomPuzzle();
      }
    }
  }

  ngOnDestroy(): void {
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
    this.stopBgTiles();
    if (this.insufficientTimer) { clearTimeout(this.insufficientTimer); this.insufficientTimer = null; }
  }

  // ── Tutorial ─────────────────────────────────────────────
  setTutorialPhase(phase: TutorialPhase): void {
    this.tutorialPhase.set(phase);
    // Phase 2 highlights the two cells user must swap
    if (phase === 2) {
      this.tutorialHighlightCells.set([{ row: 0, col: 3 }, { row: 1, col: 0 }]);
    } else {
      this.tutorialHighlightCells.set([]);
    }
  }

  // ── Game controls ────────────────────────────────────────
  onWin(): void {
    if (this.isCompleted()) return; // guard against duplicate calls
    this.tutorialPhase.set(0);
    this.tutorialHighlightCells.set([]);
    this.isCompleted.set(true);
    this.completedPraise.set(this.pickPraise());
    this.completedIcon.set(this.pickIcon());

    if (this.isTutorial()) {
      // Tutorial win: award 20 coins (same as easy level) and show stars
      const stars = this.computeStars();
      this.completedStars.set(stars);
      this.coinsEarned.set(DIFFICULTY_COINS['easy']);
      this.coinService.add(DIFFICULTY_COINS['easy']);
    } else {
      const stars = this.computeStars();
      this.completedStars.set(stars);

      const playingLevel = parseInt(localStorage.getItem(PLAYING_LEVEL_KEY) ?? localStorage.getItem(LEVEL_KEY) ?? '1', 10);
      const progress     = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);

      // Save stars (keep best score)
      const starsKey = `${STARS_KEY_PREFIX}${playingLevel}`;
      const existing = parseInt(localStorage.getItem(starsKey) ?? '0', 10);
      if (stars > existing) {
        try { localStorage.setItem(starsKey, String(stars)); } catch { /* ignore */ }
      }

      // Award coins only on first clear of this level
      const isFirstClear = playingLevel >= progress;
      if (isFirstClear) {
        const diff = LEVEL_DIFFICULTY[playingLevel] ?? 'easy';
        const earned = DIFFICULTY_COINS[diff] ?? 10;
        this.coinsEarned.set(earned);
        this.coinService.add(earned);
      } else {
        this.coinsEarned.set(0);
      }

      // Advance progress immediately so the map shows the level as done
      if (isFirstClear && playingLevel < 10) {
        try { localStorage.setItem(LEVEL_KEY, String(playingLevel + 1)); } catch { /* ignore */ }
      }
    }
  }

  onHint(): void {
    // Free during tutorial
    if (!this.isTutorial()) {
      if (!this.coinService.canAfford(HINT_COST)) {
        this.showInsufficientCoins('hint');
        return;
      }
      this.coinService.spend(HINT_COST);
    }
    this.game.hint();
  }

  onSolveWord(): void {
    if (!this.isTutorial()) {
      if (!this.coinService.canAfford(SOLVE_COST)) {
        this.showInsufficientCoins('solve');
        return;
      }
      this.coinService.spend(SOLVE_COST);
    }
    this.game.solveWord();
  }

  private insufficientTimer: ReturnType<typeof setTimeout> | null = null;
  private showInsufficientCoins(type: 'hint' | 'solve'): void {
    this.insufficientCoins.set(type);
    if (this.insufficientTimer) clearTimeout(this.insufficientTimer);
    this.insufficientTimer = setTimeout(() => {
      this.insufficientCoins.set(null);
      this.insufficientTimer = null;
    }, 5000);
  }

  nextLevel(): void {
    if (this.isTutorial()) {
      localStorage.setItem(TUTORIAL_KEY, 'true');
      this.isTutorial.set(false);
      this.tutorialPhase.set(0);
      this.tutorialHighlightCells.set([]);
      this.game.setTutorialMode(false);
      this.loadRandomPuzzle();
    } else {
      // Progress was already advanced in onWin(); just set the playing level to it
      const progress = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
      localStorage.setItem(PLAYING_LEVEL_KEY, String(progress));
      this.loadRandomPuzzle();
    }
  }

  backToMenu(): void { this.goBack.emit(); }

  restartLevel(): void {
    this.isCompleted.set(false);
    this.game.resetPuzzle();
  }

  openInfo():   void { this.showInfo = true; }
  closeInfo():  void { this.showInfo = false; }

  // ── Puzzle loading ────────────────────────────────────────
  private loadRandomPuzzle(): void {
    this.isLoading.set(true);
    this.isCompleted.set(false);
    this.game.destroy();
    Wordle7GameService.clearSavedState();
    this.startBgTiles();

    const level = parseInt(localStorage.getItem(PLAYING_LEVEL_KEY) ?? localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.puzzleService.getWordle7Level(level).pipe(retry(2)).subscribe({
      next: puzzle => {
        this.loadingPercent.set(100);
        this.stopBgTiles();
        setTimeout(() => {
          this.game.initPuzzle(puzzle);
          this.puzzleIntroTrigger.update(v => v + 1);
          this.isLoading.set(false);
          this.loadingPercent.set(0);
        }, 300);
      },
      error: () => {
        // API failed — go back to level map so user isn't stuck
        this.stopBgTiles();
        this.isLoading.set(false);
        this.loadingPercent.set(0);
        this.goBack.emit();
      },
    });
  }

  private startBgTiles(): void {
    const rows = [5, 24, 44, 64, 82];
    const tiles: BgTile[] = [];
    for (let r = 0; r < rows.length; r++) {
      for (let c = 0; c < 6; c++) {
        const i = r * 6 + c;
        tiles.push({
          id: i,
          letter: BG_LETTERS[Math.floor(Math.random() * BG_LETTERS.length)],
          x: 4 + c * 15.5 + (Math.random() - 0.5) * 8,
          y: rows[r]       + (Math.random() - 0.5) * 12,
          color: BG_COLORS[i % 3],
          delay: Math.random() * 4,
        });
      }
    }
    this.bgTiles.set(tiles);
    this.bgSwapTimer = setInterval(() => {
      const t = this.bgTiles();
      const i = Math.floor(Math.random() * t.length);
      let j = Math.floor(Math.random() * (t.length - 1));
      if (j >= i) j++;
      this.bgTiles.set(t.map((tile, idx) => {
        if (idx === i) return { ...tile, x: t[j].x, y: t[j].y };
        if (idx === j) return { ...tile, x: t[i].x, y: t[i].y };
        return tile;
      }));
    }, 1200);
  }

  private stopBgTiles(): void {
    if (this.bgSwapTimer) { clearInterval(this.bgSwapTimer); this.bgSwapTimer = null; }
    this.bgTiles.set([]);
  }

}
