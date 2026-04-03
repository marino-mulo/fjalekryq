import { Injectable, signal, computed } from '@angular/core';
import { Wordle7Puzzle, WordEntry } from '../../core/models/wordle7-puzzle.model';

export type CellColor = 'green' | 'yellow' | 'grey';

interface SavedGameState {
  puzzle: Wordle7Puzzle;
  grid: string[][];
  swapCount: number;
  hintCount: number;
  totalSwapCount: number;
  level: number;
}

const STORAGE_KEY        = 'wordle7_saved_game';
const HINT_COOLDOWN_KEY  = 'wordle7_hint_cooldown_end';
const SOLVE_COOLDOWN_KEY = 'wordle7_solve_cooldown_end';
const LEVEL_KEY          = 'fjalekryq_level';

@Injectable()
export class Wordle7GameService {
  // Puzzle data
  private solutionGrid: string[][] = [];
  private wordList: WordEntry[] = [];
  private gridSize = 7;
  private currentPuzzle: Wordle7Puzzle | null = null;
  private tutorialMode = false;

  /** Prevent tutorial swaps from overwriting real saved game state */
  setTutorialMode(enabled: boolean): void { this.tutorialMode = enabled; }

  // Pre-computed: which words pass through each cell (built once per puzzle)
  private cellToWords: Map<string, number[]> = new Map();

  // Reactive state
  readonly grid = signal<string[][]>([]);
  readonly selectedCell = signal<{ row: number; col: number } | null>(null);
  readonly gameWon = signal(false);
  readonly gameLost = signal(false);
  readonly swapCount = signal(0);       // player swaps only (counts toward limit)
  readonly totalSwapCount = signal(0);  // all swaps including hints (display)
  readonly swapLimit = signal(0);

  // Animation: last swapped cells [ { row, col, fromRow, fromCol }, ... ]
  readonly lastSwap = signal<Array<{ row: number; col: number; fromRow: number; fromCol: number }> | null>(null);

  // Hint state
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  readonly hintSwappedCells = signal<{ row: number; col: number }[]>([]);
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;
  private hintMessageTimer: ReturnType<typeof setTimeout> | null = null;
  private hintSwapTimer: ReturnType<typeof setTimeout> | null = null;

  readonly canHint = computed(() => !this.gameWon() && !this.gameLost() && !this.hintCooldown());

  // Solve-word state (30s cooldown between uses)
  readonly solveWordCooldown = signal(false);
  readonly solveWordCooldownRemaining = signal(0);
  private solveWordCooldownInterval: ReturnType<typeof setInterval> | null = null;
  readonly canSolveWord = computed(() => !this.gameWon() && !this.gameLost() && !this.solveWordCooldown());
  readonly solveWordUsed = signal(false);

  /** Remaining swaps the player can make */
  readonly swapsRemaining = computed(() => Math.max(0, this.swapLimit() - this.swapCount()));

  /** Get the current grid size */
  getGridSize(): number { return this.gridSize; }

  /**
   * Wordle-style color for each cell: green / yellow / grey.
   */
  readonly cellColors = computed(() => {
    const g = this.grid();
    const size = this.gridSize;
    const colors = new Map<string, CellColor>();
    if (g.length === 0 || this.solutionGrid.length === 0) return colors;

    // Step 1: Mark greens
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (g[r][c] === 'X') continue;
        if (g[r][c] === this.solutionGrid[r][c]) {
          colors.set(`${r},${c}`, 'green');
        }
      }
    }

    // Step 2: For each word, determine yellows with frequency counting
    const yellowCells = new Set<string>();

    for (let wi = 0; wi < this.wordList.length; wi++) {
      const w = this.wordList[wi];
      const positions: [number, number][] = [];
      for (let j = 0; j < w.word.length; j++) {
        const r = w.direction === 'horizontal' ? w.row : w.row + j;
        const c = w.direction === 'horizontal' ? w.col + j : w.col;
        positions.push([r, c]);
      }

      const solutionLetters = positions.map(([r, c]) => this.solutionGrid[r][c]);
      const currentLetters = positions.map(([r, c]) => g[r][c]);

      // Count remaining solution letter frequencies (excluding green matches)
      const remaining: Record<string, number> = {};
      for (let j = 0; j < positions.length; j++) {
        if (currentLetters[j] === solutionLetters[j]) continue;
        const sl = solutionLetters[j];
        remaining[sl] = (remaining[sl] || 0) + 1;
      }

      // Distribute yellows to non-green positions
      for (let j = 0; j < positions.length; j++) {
        if (currentLetters[j] === solutionLetters[j]) continue;
        const key = `${positions[j][0]},${positions[j][1]}`;
        const letter = currentLetters[j];
        if (remaining[letter] && remaining[letter] > 0) {
          yellowCells.add(key);
          remaining[letter]--;
        }
      }
    }

    // Step 3: Assign yellow or grey to non-green cells
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (g[r][c] === 'X') continue;
        const key = `${r},${c}`;
        if (colors.has(key)) continue;
        colors.set(key, yellowCells.has(key) ? 'yellow' : 'grey');
      }
    }

    return colors;
  });

  // Getters
  getWords(): WordEntry[] { return this.wordList; }
  getSolution(): string[][] { return this.solutionGrid; }

  initPuzzle(puzzle: Wordle7Puzzle): void {
    this.currentPuzzle = puzzle;
    this.gridSize = puzzle.gridSize ?? 7;
    this.solutionGrid = puzzle.solution.map(r => [...r]);
    this.wordList = puzzle.words;
    this.swapLimit.set(puzzle.swapLimit ?? 999);
    this.gameWon.set(false);
    this.gameLost.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(0);
    this.totalSwapCount.set(0);
    this.solveWordUsed.set(false);
    this.clearHintState();
    this.solveWordCooldown.set(false);
    this.solveWordCooldownRemaining.set(0);
    if (this.solveWordCooldownInterval) {
      clearInterval(this.solveWordCooldownInterval);
      this.solveWordCooldownInterval = null;
    }
    this.buildCellToWords();

    const scrambled = this.scrambleGrid(this.solutionGrid);
    this.grid.set(scrambled);
    this.saveState();
  }

  /** Restore a saved game state (grid + counts) without re-scrambling */
  restorePuzzle(puzzle: Wordle7Puzzle, grid: string[][], swapCount: number, hintCount: number, totalSwapCount?: number): void {
    this.currentPuzzle = puzzle;
    this.gridSize = puzzle.gridSize ?? 7;
    this.solutionGrid = puzzle.solution.map(r => [...r]);
    this.wordList = puzzle.words;
    this.swapLimit.set(puzzle.swapLimit ?? 999);
    this.gameWon.set(false);
    this.gameLost.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(swapCount);
    this.totalSwapCount.set(totalSwapCount ?? swapCount);
    this.clearHintState();
    this.hintCount.set(hintCount);
    this.buildCellToWords();
    this.grid.set(grid);
    this.restoreCooldowns();
  }

  /** Restore cooldowns that were still active before a page refresh */
  private restoreCooldowns(): void {
    const now = Date.now();

    const hintEnd = parseInt(localStorage.getItem(HINT_COOLDOWN_KEY) ?? '0', 10);
    const hintRemaining = Math.ceil((hintEnd - now) / 1000);
    if (hintRemaining > 0) {
      this.hintCooldown.set(true);
      this.hintCooldownRemaining.set(hintRemaining);
      this.hintCooldownInterval = setInterval(() => {
        const r = this.hintCooldownRemaining() - 1;
        this.hintCooldownRemaining.set(r);
        if (r <= 0) {
          this.hintCooldown.set(false);
          this.hintCooldownRemaining.set(0);
          try { localStorage.removeItem(HINT_COOLDOWN_KEY); } catch { /* ignore */ }
          if (this.hintCooldownInterval) { clearInterval(this.hintCooldownInterval); this.hintCooldownInterval = null; }
        }
      }, 1000);
    }

    const solveEnd = parseInt(localStorage.getItem(SOLVE_COOLDOWN_KEY) ?? '0', 10);
    const solveRemaining = Math.ceil((solveEnd - now) / 1000);
    if (solveRemaining > 0) {
      this.solveWordCooldown.set(true);
      this.solveWordCooldownRemaining.set(solveRemaining);
      this.solveWordCooldownInterval = setInterval(() => {
        const r = this.solveWordCooldownRemaining() - 1;
        this.solveWordCooldownRemaining.set(r);
        if (r <= 0) {
          this.solveWordCooldown.set(false);
          this.solveWordCooldownRemaining.set(0);
          try { localStorage.removeItem(SOLVE_COOLDOWN_KEY); } catch { /* ignore */ }
          if (this.solveWordCooldownInterval) { clearInterval(this.solveWordCooldownInterval); this.solveWordCooldownInterval = null; }
        }
      }, 1000);
    }
  }

  /** Save current game state to localStorage */
  private saveState(): void {
    if (this.tutorialMode) return;
    if (!this.currentPuzzle || this.gameWon()) return;
    const state: SavedGameState = {
      puzzle: this.currentPuzzle,
      grid: this.grid().map(r => [...r]),
      swapCount: this.swapCount(),
      hintCount: this.hintCount(),
      totalSwapCount: this.totalSwapCount(),
      level: parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10),
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch { /* quota exceeded – ignore */ }
  }

  /** Load saved game state from localStorage */
  static loadSavedState(): SavedGameState | null {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      return JSON.parse(raw) as SavedGameState;
    } catch {
      return null;
    }
  }

  /** Clear saved game state and cooldown timestamps */
  static clearSavedState(): void {
    try {
      localStorage.removeItem(STORAGE_KEY);
      localStorage.removeItem(HINT_COOLDOWN_KEY);
      localStorage.removeItem(SOLVE_COOLDOWN_KEY);
    } catch { /* ignore */ }
  }

  /** Build lookup: cell key -> word indices that pass through it */
  private buildCellToWords(): void {
    this.cellToWords.clear();
    for (let wi = 0; wi < this.wordList.length; wi++) {
      const w = this.wordList[wi];
      for (let j = 0; j < w.word.length; j++) {
        const r = w.direction === 'horizontal' ? w.row : w.row + j;
        const c = w.direction === 'horizontal' ? w.col + j : w.col;
        const key = `${r},${c}`;
        if (!this.cellToWords.has(key)) this.cellToWords.set(key, []);
        this.cellToWords.get(key)!.push(wi);
      }
    }
  }

  /** Scramble all letter cells randomly */
  private scrambleGrid(solution: string[][]): string[][] {
    const size = this.gridSize;
    const letters: string[] = [];
    const positions: [number, number][] = [];

    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (solution[r][c] !== 'X') {
          letters.push(solution[r][c]);
          positions.push([r, c]);
        }
      }
    }

    let attempts = 0;
    let shuffled: string[];
    do {
      shuffled = [...letters];
      for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
      }
      attempts++;
    } while (attempts < 100 && shuffled.every((l, i) => l === letters[i]));

    const grid = solution.map(r => [...r]);
    for (let i = 0; i < positions.length; i++) {
      const [r, c] = positions[i];
      grid[r][c] = shuffled[i];
    }
    return grid;
  }

  /** Is a cell locked (green = correct position)? */
  isCellLocked(row: number, col: number): boolean {
    return this.cellColors().get(`${row},${col}`) === 'green';
  }

  /** Handle cell selection / swap */
  selectCell(row: number, col: number): void {
    if (this.gameWon() || this.gameLost()) return;
    const g = this.grid();
    if (g[row][col] === 'X') return;
    if (this.isCellLocked(row, col)) return;

    const selected = this.selectedCell();

    if (!selected) {
      this.selectedCell.set({ row, col });
      return;
    }

    if (selected.row === row && selected.col === col) {
      this.selectedCell.set(null);
      return;
    }

    this.swapCells(selected.row, selected.col, row, col);
    this.selectedCell.set(null);
  }

  /** Swap two cells (player swap — counts toward limit) */
  private swapCells(r1: number, c1: number, r2: number, c2: number): void {
    const g = this.grid().map(r => [...r]);
    const temp = g[r1][c1];
    g[r1][c1] = g[r2][c2];
    g[r2][c2] = temp;
    this.grid.set(g);
    this.lastSwap.set([
      { row: r1, col: c1, fromRow: r2, fromCol: c2 },
      { row: r2, col: c2, fromRow: r1, fromCol: c1 },
    ]);
    this.swapCount.update(v => v + 1);
    this.totalSwapCount.update(v => v + 1);

    this.checkWin();
    if (!this.gameWon()) this.checkLoss();
    this.saveState();
  }

  /** Check if grid matches solution */
  private checkWin(): void {
    const g = this.grid();
    const size = this.gridSize;
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (g[r][c] !== this.solutionGrid[r][c]) return;
      }
    }
    this.gameWon.set(true);
    Wordle7GameService.clearSavedState();
  }

  /** Check if player has exhausted their swap limit */
  private checkLoss(): void {
    if (this.swapCount() >= this.swapLimit()) {
      this.gameLost.set(true);
      this.selectedCell.set(null);
      Wordle7GameService.clearSavedState();
    }
  }

  /** Reset the puzzle: re-scramble letters */
  resetPuzzle(): void {
    this.gameWon.set(false);
    this.gameLost.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(0);
    this.totalSwapCount.set(0);
    this.solveWordUsed.set(false);
    this.clearHintState();
    this.solveWordCooldown.set(false);
    this.solveWordCooldownRemaining.set(0);
    if (this.solveWordCooldownInterval) {
      clearInterval(this.solveWordCooldownInterval);
      this.solveWordCooldownInterval = null;
    }
    Wordle7GameService.clearSavedState();
    const scrambled = this.scrambleGrid(this.solutionGrid);
    this.grid.set(scrambled);
  }

  /**
   * Hint: find a wrongly-placed letter and swap it into its correct position.
   * 10s cooldown between hints.
   */
  hint(): void {
    if (!this.canHint()) return;
    this.hintCount.update(v => v + 1);

    const g = this.grid();
    const size = this.gridSize;

    // Find all wrong cells (not X, not matching solution)
    const wrongCells: { row: number; col: number }[] = [];
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (g[r][c] !== 'X' && g[r][c] !== this.solutionGrid[r][c]) {
          wrongCells.push({ row: r, col: c });
        }
      }
    }

    if (wrongCells.length === 0) return;

    // Pick a random wrong cell
    const target = wrongCells[Math.floor(Math.random() * wrongCells.length)];
    const correctLetter = this.solutionGrid[target.row][target.col];

    // Find where the correct letter currently sits (another wrong cell that has it)
    let sourceCell: { row: number; col: number } | null = null;
    for (const cell of wrongCells) {
      if (cell.row === target.row && cell.col === target.col) continue;
      if (g[cell.row][cell.col] === correctLetter) {
        sourceCell = cell;
        break;
      }
    }

    if (!sourceCell) {
      for (let r = 0; r < size; r++) {
        for (let c = 0; c < size; c++) {
          if (r === target.row && c === target.col) continue;
          if (g[r][c] === correctLetter && g[r][c] !== this.solutionGrid[r][c]) {
            sourceCell = { row: r, col: c };
            break;
          }
        }
        if (sourceCell) break;
      }
    }

    if (!sourceCell) return;

    // Perform the swap (does NOT count toward move limit)
    const newGrid = g.map(r => [...r]);
    const temp = newGrid[target.row][target.col];
    newGrid[target.row][target.col] = newGrid[sourceCell.row][sourceCell.col];
    newGrid[sourceCell.row][sourceCell.col] = temp;
    this.grid.set(newGrid);
    this.lastSwap.set([
      { row: target.row, col: target.col, fromRow: sourceCell.row, fromCol: sourceCell.col },
      { row: sourceCell.row, col: sourceCell.col, fromRow: target.row, fromCol: target.col },
    ]);
    this.totalSwapCount.update(v => v + 1);
    this.selectedCell.set(null);

    // Highlight the two swapped cells
    this.hintSwappedCells.set([target, sourceCell]);
    if (this.hintSwapTimer) clearTimeout(this.hintSwapTimer);
    this.hintSwapTimer = setTimeout(() => {
      this.hintSwappedCells.set([]);
      this.hintSwapTimer = null;
    }, 2000);

    this.showHintMessage('Një shkronjë u vendos në vendin e duhur!');
    this.checkWin();
    this.saveState();

    // 10-second cooldown (persisted so refresh doesn't reset it)
    try { localStorage.setItem(HINT_COOLDOWN_KEY, String(Date.now() + 10000)); } catch { /* ignore */ }
    this.hintCooldown.set(true);
    this.hintCooldownRemaining.set(10);
    this.hintCooldownInterval = setInterval(() => {
      const r = this.hintCooldownRemaining() - 1;
      this.hintCooldownRemaining.set(r);
      if (r <= 0) {
        this.hintCooldown.set(false);
        this.hintCooldownRemaining.set(0);
        try { localStorage.removeItem(HINT_COOLDOWN_KEY); } catch { /* ignore */ }
        if (this.hintCooldownInterval) {
          clearInterval(this.hintCooldownInterval);
          this.hintCooldownInterval = null;
        }
      }
    }, 1000);
  }

  private showHintMessage(msg: string): void {
    this.hintMessage.set(msg);
    if (this.hintMessageTimer) clearTimeout(this.hintMessageTimer);
    this.hintMessageTimer = setTimeout(() => {
      this.hintMessage.set('');
      this.hintMessageTimer = null;
    }, 4000);
  }

  private clearHintState(): void {
    this.hintMessage.set('');
    this.hintCooldown.set(false);
    this.hintCooldownRemaining.set(0);
    this.hintSwappedCells.set([]);
    if (this.hintCooldownInterval) {
      clearInterval(this.hintCooldownInterval);
      this.hintCooldownInterval = null;
    }
    if (this.hintMessageTimer) {
      clearTimeout(this.hintMessageTimer);
      this.hintMessageTimer = null;
    }
    if (this.hintSwapTimer) {
      clearTimeout(this.hintSwapTimer);
      this.hintSwapTimer = null;
    }
  }

  /**
   * Solve the 2nd biggest word: sort words by length descending,
   * pick the 2nd one, and place all its letters in the correct positions.
   * 30s cooldown between uses.
   */
  solveWord(): void {
    if (!this.canSolveWord()) return;
    this.solveWordUsed.set(true);

    // Sort words by length descending and pick the 2nd unsolved one
    const sorted = [...this.wordList].sort((a, b) => b.word.length - a.word.length);
    const g = this.grid();
    const target = sorted.find((w, i) => {
      if (i < 1) return false; // skip top 1
      // Check if word is already fully solved
      for (let j = 0; j < w.word.length; j++) {
        const r = w.direction === 'horizontal' ? w.row : w.row + j;
        const c = w.direction === 'horizontal' ? w.col + j : w.col;
        if (g[r][c] !== this.solutionGrid[r][c]) return true; // has wrong letters, pick this one
      }
      return false;
    }) ?? sorted[Math.min(1, sorted.length - 1)];
    if (!target) return;

    // Get positions of the target word
    const positions: { row: number; col: number }[] = [];
    for (let j = 0; j < target.word.length; j++) {
      const r = target.direction === 'horizontal' ? target.row : target.row + j;
      const c = target.direction === 'horizontal' ? target.col + j : target.col;
      positions.push({ row: r, col: c });
    }

    // Place the correct letters by finding where each needed letter currently is
    const newGrid = this.grid().map(r => [...r]);
    const swapAnim: Array<{ row: number; col: number; fromRow: number; fromCol: number }> = [];

    for (let j = 0; j < positions.length; j++) {
      const pos = positions[j];
      const correctLetter = this.solutionGrid[pos.row][pos.col];

      if (newGrid[pos.row][pos.col] === correctLetter) continue; // already correct

      // Find where this letter currently sits
      for (let r = 0; r < this.gridSize; r++) {
        for (let c = 0; c < this.gridSize; c++) {
          if (r === pos.row && c === pos.col) continue;
          if (newGrid[r][c] === correctLetter && newGrid[r][c] !== this.solutionGrid[r][c]) {
            // Swap and record animation source
            newGrid[r][c] = newGrid[pos.row][pos.col];
            newGrid[pos.row][pos.col] = correctLetter;
            swapAnim.push({ row: pos.row, col: pos.col, fromRow: r, fromCol: c });
            swapAnim.push({ row: r, col: c, fromRow: pos.row, fromCol: pos.col });
            break;
          }
        }
        if (newGrid[pos.row][pos.col] === correctLetter) break;
      }
    }

    this.grid.set(newGrid);
    this.lastSwap.set(swapAnim.length > 0 ? swapAnim : positions.map(pos => ({ row: pos.row, col: pos.col, fromRow: pos.row, fromCol: pos.col })));
    this.totalSwapCount.update(v => v + target.word.length);
    this.selectedCell.set(null);

    // Highlight the solved word cells
    this.hintSwappedCells.set(positions);
    if (this.hintSwapTimer) clearTimeout(this.hintSwapTimer);
    this.hintSwapTimer = setTimeout(() => {
      this.hintSwappedCells.set([]);
      this.hintSwapTimer = null;
    }, 2500);

    this.showHintMessage(`Fjala "${target.word}" u zgjidh!`);
    this.checkWin();
    if (!this.gameWon()) this.checkLoss();
    this.saveState();

    // 30-second cooldown (persisted so refresh doesn't reset it)
    try { localStorage.setItem(SOLVE_COOLDOWN_KEY, String(Date.now() + 30000)); } catch { /* ignore */ }
    this.solveWordCooldown.set(true);
    this.solveWordCooldownRemaining.set(30);
    this.solveWordCooldownInterval = setInterval(() => {
      const r = this.solveWordCooldownRemaining() - 1;
      this.solveWordCooldownRemaining.set(r);
      if (r <= 0) {
        this.solveWordCooldown.set(false);
        this.solveWordCooldownRemaining.set(0);
        try { localStorage.removeItem(SOLVE_COOLDOWN_KEY); } catch { /* ignore */ }
        if (this.solveWordCooldownInterval) {
          clearInterval(this.solveWordCooldownInterval);
          this.solveWordCooldownInterval = null;
        }
      }
    }, 1000);
  }

  destroy(): void {
    this.clearHintState();
    if (this.solveWordCooldownInterval) {
      clearInterval(this.solveWordCooldownInterval);
      this.solveWordCooldownInterval = null;
    }
  }
}
