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

// tutorialPhase: 0=off, 1=step1 modal, 2=waiting swap, 3=step2 modal, 4=step3 modal, 5=step4 modal, 6=done
export type TutorialPhase = 0 | 1 | 2 | 3 | 4 | 5 | 6;

function getLevelDifficulty(level: number): string {
  if (level <= 100) return 'easy';
  if (level <= 300) return 'medium';
  if (level <= 500) return 'hard';
  return 'extreme';
}

const BG_LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split('');
const BG_COLORS  = ['gold', 'lime', 'orange', 'red', 'sky', 'violet'] as const;

interface BgTile {
  id: number; letter: string;
  x: number;  y: number;
  color: 'gold' | 'lime' | 'orange' | 'red' | 'sky' | 'violet';
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
    // Phase 2 = waiting for first swap → auto-advance to phase 3 when swap happens
    effect(() => {
      if (this.isTutorial() && this.tutorialPhase() === 2 && this.game.totalSwapCount() > 0) {
        this.tutorialPhase.set(3);
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
      const saved = Wordle7GameService.loadSavedState();
      if (saved && saved.puzzle.hash === 'tutorial_v1') {
        this.game.restorePuzzle(saved.puzzle, saved.grid, saved.swapCount, saved.hintCount, saved.totalSwapCount);
      } else {
        this.game.initPuzzle(TUTORIAL_PUZZLE);
      }
      this.tutorialPhase.set(1);
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
  }

  // ── Game controls ────────────────────────────────────────
  onWin(): void {
    this.tutorialPhase.set(0);
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
    this.startLoadingProgress();
    this.startBgTiles();

    const level = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.puzzleService.getRandomWordle7(this.lastWords, getLevelDifficulty(level)).subscribe(puzzle => {
      this.lastWords = puzzle.words.map(w => w.word);
      this.loadingPercent.set(100);
      this.stopLoadingProgress();
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
