import { Injectable, signal, computed } from '@angular/core';
import { SnakePuzzle } from '../../core/models/snake-puzzle.model';

export const EMPTY = 0;
export const MARK_X = 1;
export const SNAKE = 2;

@Injectable()
export class SnakeGameService {
  private size = 0;
  private rowClues: number[] = [];
  private colClues: number[] = [];
  private headRow = 0;
  private headCol = 0;
  private tailRow = 0;
  private tailCol = 0;
  private snakeLength = 0;
  private givens: Set<string> = new Set();
  private solution: number[][] = [];

  readonly board = signal<number[][]>([]);
  readonly gameWon = signal(false);
  readonly timerSeconds = signal(0);
  readonly timerDisabled = signal(false);
  readonly isRestored = signal(false);
  readonly conflictCells = signal<{ row: number; col: number }[]>([]);
  readonly hintCells = signal<{ row: number; col: number }[]>([]);
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  readonly checkCount = signal(0);

  private hintTimeout: ReturnType<typeof setTimeout> | null = null;
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;
  private timerInterval: ReturnType<typeof setInterval> | null = null;

  private history: number[][][] = [];
  private readonly historyLength = signal(0);

  readonly snakeCellCount = computed(() => {
    let count = 0;
    for (const row of this.board()) for (const cell of row) if (cell === SNAKE) count++;
    return count;
  });

  readonly canUndo = computed(() => this.historyLength() > 0 && !this.gameWon());
  readonly canHint = computed(() => !this.gameWon() && !this.hintCooldown());

  getSize() { return this.size; }
  getRowClues() { return this.rowClues; }
  getColClues() { return this.colClues; }
  getHeadRow() { return this.headRow; }
  getHeadCol() { return this.headCol; }
  getTailRow() { return this.tailRow; }
  getTailCol() { return this.tailCol; }
  getSnakeLength() { return this.snakeLength; }
  isGiven(row: number, col: number) { return this.givens.has(`${row},${col}`); }

  initPuzzle(puzzle: SnakePuzzle): void {
    this.size = puzzle.size;
    this.rowClues = puzzle.rowClues;
    this.colClues = puzzle.colClues;
    this.headRow = puzzle.headRow;
    this.headCol = puzzle.headCol;
    this.tailRow = puzzle.tailRow;
    this.tailCol = puzzle.tailCol;
    this.snakeLength = puzzle.snakeLength;
    this.solution = puzzle.solution;

    this.givens = new Set();
    for (const [r, c] of puzzle.givens) {
      this.givens.add(`${r},${c}`);
    }

    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.history = [];
    this.historyLength.set(0);
    this.clearHint();
    this.conflictCells.set([]);

    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) {
      b.push(new Array(this.size).fill(EMPTY));
    }
    // Pre-fill head and tail as SNAKE (they are always part of path)
    b[this.headRow][this.headCol] = SNAKE;
    b[this.tailRow][this.tailCol] = SNAKE;
    // Pre-fill givens
    for (const [r, c] of puzzle.givens) {
      b[r][c] = SNAKE;
    }
    this.board.set(b);
    this.startTimer();
  }

  toggleCell(row: number, col: number): void {
    if (this.gameWon()) return;
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return;
    // Head, tail, and givens cannot be toggled
    if (row === this.headRow && col === this.headCol) return;
    if (row === this.tailRow && col === this.tailCol) return;
    if (this.givens.has(`${row},${col}`)) return;

    this.clearHint();
    const b = this.board().map(r => [...r]);
    const current = b[row][col];

    this.history.push(this.board().map(r => [...r]));
    this.historyLength.set(this.history.length);

    // Cycle: empty → X → snake → empty
    if (current === EMPTY) {
      b[row][col] = MARK_X;
    } else if (current === MARK_X) {
      b[row][col] = SNAKE;
    } else {
      b[row][col] = EMPTY;
    }

    this.board.set(b);
    this.updateConflicts();

    if (b[row][col] === SNAKE) this.checkWin();
  }

  undo(): void {
    if (this.history.length === 0 || this.gameWon()) return;
    const prev = this.history.pop()!;
    this.historyLength.set(this.history.length);
    this.board.set(prev);
    this.updateConflicts();
  }

  hint(): void {
    if (!this.canHint()) return;
    this.hintCount.update(v => v + 1);
    this.clearHint();

    const b = this.board();
    const n = this.size;

    // First: correct mistakes
    const correction = this.correctMistake(b, n);
    if (correction) {
      this.history.push(b.map(r => [...r]));
      this.historyLength.set(this.history.length);
      this.board.set(correction.board);
      this.updateConflicts();
      this.hintCells.set(correction.cells);
      this.hintMessage.set(correction.message);
      this.scheduleHintClear();
      this.startHintCooldown();
      return;
    }

    // Second: mark a cell that must be SNAKE (row/col clue forces it)
    const forced = this.findForcedSnakeCell(b, n);
    if (forced) {
      this.history.push(b.map(r => [...r]));
      this.historyLength.set(this.history.length);
      const newBoard = b.map(r => [...r]);
      newBoard[forced.row][forced.col] = SNAKE;
      this.board.set(newBoard);
      this.updateConflicts();
      this.hintCells.set([forced]);
      this.hintMessage.set(`Rreshti/kolona ka hapësirë vetëm aty — vizato atë qelizë.`);
      this.scheduleHintClear();
      this.startHintCooldown();
      return;
    }

    // Third: mark a cell that must be X (row/col already full)
    const xCell = this.findForcedXCell(b, n);
    if (xCell) {
      this.history.push(b.map(r => [...r]));
      this.historyLength.set(this.history.length);
      const newBoard = b.map(r => [...r]);
      newBoard[xCell.row][xCell.col] = MARK_X;
      this.board.set(newBoard);
      this.updateConflicts();
      this.hintCells.set([xCell]);
      this.hintMessage.set(`Rreshti/kolona është plotësuar — kjo qelizë nuk mund të jetë gjarpër.`);
      this.scheduleHintClear();
      this.startHintCooldown();
      return;
    }

    this.hintMessage.set('Nuk gjeta ndihmë — shiko rreshtat dhe kolonat me pak hapësirë.');
    this.hintTimeout = setTimeout(() => this.hintMessage.set(''), 4000);
    this.startHintCooldown();
  }

  private correctMistake(b: number[][], n: number): {
    board: number[][];
    cells: { row: number; col: number }[];
    message: string;
  } | null {
    const newBoard = b.map(r => [...r]);
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        const inSolution = this.solution[r][c] > 0;
        if (b[r][c] === SNAKE && !inSolution) {
          newBoard[r][c] = EMPTY;
          return { board: newBoard, cells: [{ row: r, col: c }], message: '1 qelizë e gabuar u hoq — provo përsëri!' };
        }
        if (b[r][c] === MARK_X && inSolution) {
          newBoard[r][c] = EMPTY;
          return { board: newBoard, cells: [{ row: r, col: c }], message: '1 X e gabuar u fshi — provo përsëri!' };
        }
      }
    }
    return null;
  }

  private findForcedSnakeCell(b: number[][], n: number): { row: number; col: number } | null {
    // If a row has exactly (clue - currentSnake) empty cells left, they must all be snake
    for (let r = 0; r < n; r++) {
      const snakeInRow = b[r].filter(c => c === SNAKE).length;
      const emptyInRow = b[r].filter(c => c === EMPTY).length;
      const needed = this.rowClues[r] - snakeInRow;
      if (needed > 0 && needed === emptyInRow) {
        for (let c = 0; c < n; c++) {
          if (b[r][c] === EMPTY && this.solution[r][c] > 0) return { row: r, col: c };
        }
      }
    }
    for (let c = 0; c < n; c++) {
      let snakeInCol = 0, emptyInCol = 0;
      for (let r = 0; r < n; r++) {
        if (b[r][c] === SNAKE) snakeInCol++;
        if (b[r][c] === EMPTY) emptyInCol++;
      }
      const needed = this.colClues[c] - snakeInCol;
      if (needed > 0 && needed === emptyInCol) {
        for (let r = 0; r < n; r++) {
          if (b[r][c] === EMPTY && this.solution[r][c] > 0) return { row: r, col: c };
        }
      }
    }
    return null;
  }

  private findForcedXCell(b: number[][], n: number): { row: number; col: number } | null {
    for (let r = 0; r < n; r++) {
      const snakeInRow = b[r].filter(c => c === SNAKE).length;
      if (snakeInRow >= this.rowClues[r]) {
        for (let c = 0; c < n; c++) {
          if (b[r][c] === EMPTY) return { row: r, col: c };
        }
      }
    }
    for (let c = 0; c < n; c++) {
      let snakeInCol = 0;
      for (let r = 0; r < n; r++) if (b[r][c] === SNAKE) snakeInCol++;
      if (snakeInCol >= this.colClues[c]) {
        for (let r = 0; r < n; r++) {
          if (b[r][c] === EMPTY) return { row: r, col: c };
        }
      }
    }
    return null;
  }

  private scheduleHintClear(): void {
    this.hintTimeout = setTimeout(() => {
      this.hintCells.set([]);
      this.hintMessage.set('');
      this.hintTimeout = null;
    }, 5000);
  }

  private detectConflicts(b: number[][]): { row: number; col: number }[] {
    const n = this.size;
    const conflictSet = new Set<string>();

    // Row over-limit
    for (let r = 0; r < n; r++) {
      const count = b[r].filter(c => c === SNAKE).length;
      if (count > this.rowClues[r]) {
        for (let c = 0; c < n; c++) if (b[r][c] === SNAKE) conflictSet.add(`${r},${c}`);
      }
    }

    // Col over-limit
    for (let c = 0; c < n; c++) {
      let count = 0;
      for (let r = 0; r < n; r++) if (b[r][c] === SNAKE) count++;
      if (count > this.colClues[c]) {
        for (let r = 0; r < n; r++) if (b[r][c] === SNAKE) conflictSet.add(`${r},${c}`);
      }
    }

    return Array.from(conflictSet).map(key => {
      const [r, c] = key.split(',').map(Number);
      return { row: r, col: c };
    });
  }

  updateConflicts(): void {
    this.conflictCells.set(this.detectConflicts(this.board()));
  }

  triggerWinCheck(): void {
    this.checkWin();
  }

  private checkWin(): void {
    const b = this.board();
    const n = this.size;

    // Row/col clues satisfied
    for (let r = 0; r < n; r++) {
      const count = b[r].filter(c => c === SNAKE).length;
      if (count !== this.rowClues[r]) return;
    }
    for (let c = 0; c < n; c++) {
      let count = 0;
      for (let r = 0; r < n; r++) if (b[r][c] === SNAKE) count++;
      if (count !== this.colClues[c]) return;
    }

    // Total snake cells matches snakeLength
    let total = 0;
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (b[r][c] === SNAKE) total++;
    if (total !== this.snakeLength) return;

    // No conflicts
    if (this.detectConflicts(b).length > 0) return;

    // Continuous path from head to tail
    if (!this.isValidPath(b)) return;

    // Auto-fill remaining empty cells with X
    const filled = b.map(r => [...r]);
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (filled[r][c] === EMPTY) filled[r][c] = MARK_X;
    this.board.set(filled);

    this.gameWon.set(true);
    this.stopTimer();
  }

  private isValidPath(b: number[][]): boolean {
    const n = this.size;
    const visited = new Set<string>();
    const queue: [number, number][] = [[this.headRow, this.headCol]];
    visited.add(`${this.headRow},${this.headCol}`);

    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

    while (queue.length > 0) {
      const [r, c] = queue.shift()!;
      for (const [dr, dc] of dirs) {
        const nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n && !visited.has(`${nr},${nc}`) && b[nr][nc] === SNAKE) {
          visited.add(`${nr},${nc}`);
          queue.push([nr, nc]);
        }
      }
    }

    // All snake cells must be reachable from head
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === SNAKE && !visited.has(`${r},${c}`)) return false;
      }
    }

    // Tail must be reachable
    return visited.has(`${this.tailRow},${this.tailCol}`);
  }

  checkCorrect(): boolean {
    const b = this.board();
    const n = this.size;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        const inSolution = this.solution[r][c] > 0;
        if (b[r][c] === SNAKE && !inSolution) return false;
        if (b[r][c] === MARK_X && inSolution) return false;
      }
    }
    return true;
  }

  reset(): void {
    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) b.push(new Array(this.size).fill(EMPTY));
    b[this.headRow][this.headCol] = SNAKE;
    b[this.tailRow][this.tailCol] = SNAKE;
    for (const key of this.givens) {
      const [r, c] = key.split(',').map(Number);
      b[r][c] = SNAKE;
    }
    this.board.set(b);
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.history = [];
    this.historyLength.set(0);
    this.clearHint();
    this.conflictCells.set([]);
    // Keep timer running without resetting seconds
    this.stopTimer();
    this.timerInterval = setInterval(() => this.timerSeconds.update(v => v + 1), 1000);
  }

  restoreCompleted(savedBoard: number[][]): void {
    this.isRestored.set(true);
    this.board.set(savedBoard);
    this.gameWon.set(true);
    this.timerDisabled.set(true);
    this.history = [];
    this.historyLength.set(0);
    this.stopTimer();
  }

  restorePaused(savedBoard: number[][], savedTimer: number, savedHistory?: number[][][]): void {
    this.board.set(savedBoard);
    this.timerSeconds.set(savedTimer);
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.history = savedHistory ?? [];
    this.historyLength.set(this.history.length);
    this.stopTimer();
  }

  getProgressSnapshot(): { board: number[][]; timerSeconds: number; history: number[][][] } | null {
    if (this.gameWon() || this.isRestored() || this.timerDisabled()) return null;
    const b = this.board();
    let hasMove = false;
    for (const row of b) { for (const cell of row) { if (cell !== EMPTY) { hasMove = true; break; } } if (hasMove) break; }
    if (!hasMove) return null;
    return { board: b.map(r => [...r]), timerSeconds: this.timerSeconds(), history: this.history.map(h => h.map(r => [...r])) };
  }

  pauseTimer(): void { this.stopTimer(); }
  resumeTimer(): void {
    if (this.gameWon() || this.timerDisabled()) return;
    this.stopTimer();
    this.timerInterval = setInterval(() => this.timerSeconds.update(v => v + 1), 1000);
  }

  private startTimer(): void {
    this.stopTimer();
    this.timerSeconds.set(0);
    this.hintCount.set(0);
    this.checkCount.set(0);
    this.timerInterval = setInterval(() => this.timerSeconds.update(v => v + 1), 1000);
  }

  private stopTimer(): void {
    if (this.timerInterval) { clearInterval(this.timerInterval); this.timerInterval = null; }
  }

  formatTime(seconds: number): string {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    const parts: string[] = [];
    if (h > 0) parts.push(`${h} orë`);
    if (m > 0) parts.push(`${m} minuta`);
    if (s > 0 || parts.length === 0) parts.push(`${s} sekonda`);
    return parts.join(' e ');
  }

  formatTimeClock(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return m.toString().padStart(2, '0') + ':' + s.toString().padStart(2, '0');
  }

  private startHintCooldown(): void {
    this.hintCooldown.set(true);
    this.hintCooldownRemaining.set(5);
    this.hintCooldownInterval = setInterval(() => {
      const r = this.hintCooldownRemaining() - 1;
      this.hintCooldownRemaining.set(r);
      if (r <= 0) {
        this.hintCooldown.set(false);
        this.hintCooldownRemaining.set(0);
        if (this.hintCooldownInterval) { clearInterval(this.hintCooldownInterval); this.hintCooldownInterval = null; }
      }
    }, 1000);
  }

  private clearHint(): void {
    if (this.hintTimeout) { clearTimeout(this.hintTimeout); this.hintTimeout = null; }
    this.hintCells.set([]);
    this.hintMessage.set('');
    this.hintCooldown.set(false);
    this.hintCooldownRemaining.set(0);
    if (this.hintCooldownInterval) { clearInterval(this.hintCooldownInterval); this.hintCooldownInterval = null; }
  }

  destroy(): void {
    this.stopTimer();
    this.clearHint();
  }
}
