import { Component, OnInit, OnDestroy, inject, signal, Output, EventEmitter, effect } from '@angular/core';
import { Subscription } from 'rxjs';
import { Wordle7BoardComponent } from './wordle7-board/wordle7-board.component';
import { Wordle7GameService } from './wordle7-game.service';
import { PuzzleService } from '../../core/services/puzzle.service';
import { GameHeaderService } from '../../core/services/game-header.service';

const LEVEL_KEY          = 'fjalekryq_level';
const TUTORIAL_KEY       = 'fjalekryq_tutorial_done';
const FORCE_TUTORIAL_KEY = 'fjalekryq_force_tutorial';

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
  swapLimit: 40,
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
//               5=interactive hint, 6=solve modal, 7=interactive solve, 8=done banner
export type TutorialPhase = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8;

function getLevelDifficulty(level: number): string {
  if (level <= 3) return 'easy';
  if (level <= 6) return 'medium';
  if (level <= 9) return 'hard';
  return 'expert';
}

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
  imports: [Wordle7BoardComponent],
  providers: [Wordle7GameService],
  templateUrl: './wordle7.component.html',
  styleUrl: './wordle7.component.scss'
})
export class Wordle7Component implements OnInit, OnDestroy {
  private puzzleService = inject(PuzzleService);
  private gameHeader    = inject(GameHeaderService);
  game = inject(Wordle7GameService);

  @Output() goBack = new EventEmitter<void>();

  private subs: Subscription[] = [];

  showInfo = false;

  // Tutorial
  isTutorial    = signal(false);
  tutorialPhase = signal<TutorialPhase>(0);
  tutorialHighlightCells = signal<{row: number; col: number}[]>([]);

  // Completion
  isCompleted    = signal(false);
  completedPraise = signal('Bravo!');
  completedIcon   = signal('icons/rewards/rocket.svg');

  // Puzzle / loading
  isLoading      = signal(false);
  loadingPercent = signal(0);
  private lastWords: string[] = [];
  private loadingInterval: ReturnType<typeof setInterval> | null = null;

  bgTiles = signal<BgTile[]>([]);
  private bgSwapTimer: ReturnType<typeof setInterval> | null = null;

  private readonly ICONS   = ['icons/rewards/rocket.svg', 'icons/rewards/fire.svg', 'icons/rewards/trophy.svg'];
  private readonly PRAISES = ['Bravo!', 'Të lumtë!', 'Shkëlqyeshëm!', 'Fantastike!', 'Mahnitëse!'];
  private pickPraise() { return this.PRAISES[Math.floor(Math.random() * this.PRAISES.length)]; }
  private pickIcon()   { return this.ICONS[Math.floor(Math.random() * this.ICONS.length)]; }

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

    // Phase 7 → 8: advance when solve is used (cooldown starts)
    effect(() => {
      if (this.isTutorial() && this.tutorialPhase() === 7 && this.game.solveWordCooldown()) {
        this.setTutorialPhase(8);
      }
    }, { allowSignalWrites: true });
  }

  ngOnInit(): void {
    this.gameHeader.enterGame();
    this.gameHeader.gameColor.set('#22C55E');
    this.gameHeader.dayBarVisible.set(false);
    this.subs.push(this.gameHeader.infoClicked$.subscribe(() => this.openInfo()));

    const forceTutorial = localStorage.getItem(FORCE_TUTORIAL_KEY) === 'true';
    if (forceTutorial) localStorage.removeItem(FORCE_TUTORIAL_KEY);

    const level        = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    const tutorialDone = localStorage.getItem(TUTORIAL_KEY) === 'true';

    if ((level === 1 && !tutorialDone) || forceTutorial) {
      this.isTutorial.set(true);
      this.game.setTutorialMode(true);
      this.game.restorePuzzle(TUTORIAL_PUZZLE, TUTORIAL_INITIAL_GRID.map(r => [...r]), 0, 0, 0);
      this.setTutorialPhase(1);
    } else {
      const saved = Wordle7GameService.loadSavedState();
      if (saved && saved.puzzle.hash !== 'tutorial_v1') {
        this.lastWords = saved.puzzle.words.map(w => w.word);
        this.game.restorePuzzle(saved.puzzle, saved.grid, saved.swapCount, saved.hintCount, saved.totalSwapCount);
      } else {
        this.loadRandomPuzzle();
      }
    }
  }

  ngOnDestroy(): void {
    this.game.destroy();
    this.gameHeader.leaveGame();
    this.subs.forEach(s => s.unsubscribe());
    this.stopLoadingProgress();
    this.stopBgTiles();
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
    this.tutorialPhase.set(0);
    this.tutorialHighlightCells.set([]);
    this.isCompleted.set(true);
    this.completedPraise.set(this.pickPraise());
    this.completedIcon.set(this.pickIcon());
  }

  onHint(): void      { this.game.hint(); }
  onSolveWord(): void { this.game.solveWord(); }

  nextLevel(): void {
    if (this.isTutorial()) {
      localStorage.setItem(TUTORIAL_KEY, 'true');
      this.isTutorial.set(false);
      this.tutorialPhase.set(0);
      this.tutorialHighlightCells.set([]);
      this.game.setTutorialMode(false);
      this.loadRandomPuzzle();
    } else {
      const current = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
      localStorage.setItem(LEVEL_KEY, String(isNaN(current) || current < 1 ? 2 : current + 1));
      this.loadRandomPuzzle();
    }
  }

  backToMenu(): void { this.goBack.emit(); }
  openInfo():   void { this.showInfo = true; }
  closeInfo():  void { this.showInfo = false; }

  // ── Puzzle loading ────────────────────────────────────────
  private loadRandomPuzzle(): void {
    this.isLoading.set(true);
    this.isCompleted.set(false);
    this.game.destroy();
    Wordle7GameService.clearSavedState();
    this.startBgTiles();

    const level = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    // Use pre-generated level puzzle (instant) instead of on-demand generation
    this.puzzleService.getWordle7Level(level).subscribe(puzzle => {
      this.lastWords = puzzle.words.map(w => w.word);
      this.loadingPercent.set(100);
      this.stopBgTiles();
      setTimeout(() => {
        this.game.initPuzzle(puzzle);
        this.isLoading.set(false);
        this.loadingPercent.set(0);
      }, 300);
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

  private startLoadingProgress(): void {
    this.stopLoadingProgress();
    this.loadingPercent.set(0);
    let current = 0;
    this.loadingInterval = setInterval(() => {
      const rem = 90 - current;
      current = Math.min(90, current + Math.max(0.5, rem * 0.08));
      this.loadingPercent.set(Math.round(current));
    }, 100);
  }

  private stopLoadingProgress(): void {
    if (this.loadingInterval) { clearInterval(this.loadingInterval); this.loadingInterval = null; }
  }
}
