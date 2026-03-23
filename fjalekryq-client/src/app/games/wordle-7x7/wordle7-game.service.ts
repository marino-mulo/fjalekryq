import { Injectable, signal, computed } from '@angular/core';
import { Wordle7Puzzle, WordEntry } from '../../core/models/wordle7-puzzle.model';

export type CellColor = 'green' | 'yellow' | 'grey';

interface SavedGameState {
  puzzle: Wordle7Puzzle;
  grid: string[][];
  swapCount: number;
  hintCount: number;
}

const STORAGE_KEY = 'wordle7_saved_game';

@Injectable()
export class Wordle7GameService {
  // Puzzle data
  private solutionGrid: string[][] = [];
  private wordList: WordEntry[] = [];
  private gridSize = 7;
  private currentPuzzle: Wordle7Puzzle | null = null;

  // Pre-computed: which words pass through each cell (built once per puzzle)
  private cellToWords: Map<string, number[]> = new Map();

  // Reactive state
  readonly grid = signal<string[][]>([]);
  readonly selectedCell = signal<{ row: number; col: number } | null>(null);
  readonly gameWon = signal(false);
  readonly swapCount = signal(0);

  // Hint state
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  readonly hintSwappedCells = signal<{ row: number; col: number }[]>([]);
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;
  private hintMessageTimer: ReturnType<typeof setTimeout> | null = null;
  private hintSwapTimer: ReturnType<typeof setTimeout> | null = null;

  readonly canHint = computed(() => !this.gameWon() && !this.hintCooldown());

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
    this.gameWon.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(0);
    this.clearHintState();
    this.buildCellToWords();

    const scrambled = this.scrambleGrid(this.solutionGrid);
    this.grid.set(scrambled);
    this.saveState();
  }

  /** Restore a saved game state (grid + counts) without re-scrambling */
  restorePuzzle(puzzle: Wordle7Puzzle, grid: string[][], swapCount: number, hintCount: number): void {
    this.currentPuzzle = puzzle;
    this.gridSize = puzzle.gridSize ?? 7;
    this.solutionGrid = puzzle.solution.map(r => [...r]);
    this.wordList = puzzle.words;
    this.gameWon.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(swapCount);
    this.clearHintState();
    this.hintCount.set(hintCount);
    this.buildCellToWords();
    this.grid.set(grid);
  }

  /** Save current game state to localStorage */
  private saveState(): void {
    if (!this.currentPuzzle || this.gameWon()) return;
    const state: SavedGameState = {
      puzzle: this.currentPuzzle,
      grid: this.grid().map(r => [...r]),
      swapCount: this.swapCount(),
      hintCount: this.hintCount(),
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

  /** Clear saved game state */
  static clearSavedState(): void {
    try { localStorage.removeItem(STORAGE_KEY); } catch { /* ignore */ }
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
    if (this.gameWon()) return;
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

  /** Swap two cells */
  private swapCells(r1: number, c1: number, r2: number, c2: number): void {
    const g = this.grid().map(r => [...r]);
    const temp = g[r1][c1];
    g[r1][c1] = g[r2][c2];
    g[r2][c2] = temp;
    this.grid.set(g);
    this.swapCount.update(v => v + 1);

    this.checkWin();
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

  /** Reset the puzzle: re-scramble letters */
  resetPuzzle(): void {
    this.gameWon.set(false);
    this.selectedCell.set(null);
    this.swapCount.set(0);
    this.clearHintState();

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

    // Perform the swap
    const newGrid = g.map(r => [...r]);
    const temp = newGrid[target.row][target.col];
    newGrid[target.row][target.col] = newGrid[sourceCell.row][sourceCell.col];
    newGrid[sourceCell.row][sourceCell.col] = temp;
    this.grid.set(newGrid);
    this.swapCount.update(v => v + 1);
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

    // 10-second cooldown
    this.hintCooldown.set(true);
    this.hintCooldownRemaining.set(10);
    this.hintCooldownInterval = setInterval(() => {
      const r = this.hintCooldownRemaining() - 1;
      this.hintCooldownRemaining.set(r);
      if (r <= 0) {
        this.hintCooldown.set(false);
        this.hintCooldownRemaining.set(0);
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

  destroy(): void {
    this.clearHintState();
  }
}
