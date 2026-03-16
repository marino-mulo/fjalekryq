import { Injectable, signal, computed } from '@angular/core';
import { TangoPuzzle, TangoConstraint } from '../../core/models/tango-puzzle.model';

// Cell states
export const EMPTY = 0;
export const SUN = 1;
export const MOON = 2;

@Injectable()
export class TangoGameService {
  private readonly SIZE = 6;
  private solution: number[][] = [];
  private prefilled: number[][] = [];
  private constraints: TangoConstraint[] = [];

  // Reactive state
  readonly board = signal<number[][]>([]);
  readonly gameWon = signal(false);
  readonly timerSeconds = signal(0);
  readonly timerDisabled = signal(false);
  readonly isRestored = signal(false);

  // Conflict detection
  readonly conflictCells = signal<{ row: number; col: number }[]>([]);

  // Hint state
  readonly hintCells = signal<{ row: number; col: number }[]>([]);
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  readonly checkCount = signal(0);
  private hintTimeout: ReturnType<typeof setTimeout> | null = null;
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;

  // Undo history
  private history: number[][][] = [];
  private readonly historyLength = signal(0);

  // Derived
  readonly filledCount = computed(() => {
    let count = 0;
    for (const row of this.board()) {
      for (const cell of row) {
        if (cell !== EMPTY) count++;
      }
    }
    return count;
  });

  readonly canUndo = computed(() => this.historyLength() > 0 && !this.gameWon());

  private conflictTimeout: ReturnType<typeof setTimeout> | null = null;
  private timerInterval: ReturnType<typeof setInterval> | null = null;

  getSize() { return this.SIZE; }

  isPrefilled(row: number, col: number): boolean {
    return this.prefilled[row]?.[col] !== -1;
  }

  getConstraints(): TangoConstraint[] { return this.constraints; }

  initPuzzle(puzzle: TangoPuzzle): void {
    this.solution = puzzle.solution;
    this.prefilled = puzzle.prefilled;
    this.constraints = puzzle.constraints || [];
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.history = [];
    this.historyLength.set(0);
    this.clearHint();
    this.conflictCells.set([]);

    // Create board from prefilled
    const b: number[][] = [];
    for (let r = 0; r < this.SIZE; r++) {
      const row: number[] = [];
      for (let c = 0; c < this.SIZE; c++) {
        const pf = this.prefilled[r][c];
        if (pf === 0) row.push(SUN);
        else if (pf === 1) row.push(MOON);
        else row.push(EMPTY);
      }
      b.push(row);
    }
    this.board.set(b);
    this.startTimer();
  }

  toggleCell(row: number, col: number): void {
    if (this.gameWon()) return;
    if (row < 0 || row >= this.SIZE || col < 0 || col >= this.SIZE) return;
    if (this.isPrefilled(row, col)) return;

    this.clearHint();

    const b = this.board().map(r => [...r]);
    const current = b[row][col];

    // Save snapshot before change
    this.history.push(this.board().map(r => [...r]));
    this.historyLength.set(this.history.length);

    // Cycle: empty → sun → moon → empty
    if (current === EMPTY) {
      b[row][col] = SUN;
    } else if (current === SUN) {
      b[row][col] = MOON;
    } else {
      b[row][col] = EMPTY;
    }

    this.board.set(b);
    this.updateConflicts();
    this.checkWin();
  }

  undo(): void {
    if (this.history.length === 0 || this.gameWon()) return;
    const prev = this.history.pop()!;
    this.historyLength.set(this.history.length);
    this.board.set(prev);
    this.updateConflicts();
  }

  hint(): void {
    if (this.gameWon() || this.hintCooldown()) return;
    this.hintCount.update(v => v + 1);
    this.clearHint();

    const b = this.board();

    // Step 1: Check for mistakes — find a wrong cell and clear it
    for (let r = 0; r < this.SIZE; r++) {
      for (let c = 0; c < this.SIZE; c++) {
        if (this.isPrefilled(r, c)) continue;
        if (b[r][c] === EMPTY) continue;
        const expected = this.solution[r][c] === 0 ? SUN : MOON;
        if (b[r][c] !== expected) {
          const newBoard = b.map(row => [...row]);
          newBoard[r][c] = EMPTY;
          this.history.push(b.map(row => [...row]));
          this.historyLength.set(this.history.length);
          this.board.set(newBoard);
          this.updateConflicts();
          this.hintCells.set([{ row: r, col: c }]);
          this.hintMessage.set('Një simbol i gabuar u fshi — provo përsëri!');
          this.scheduleHintClear();
          this.startHintCooldown();
          return;
        }
      }
    }

    // Step 2: Find an empty cell that can be deduced and reveal it
    for (let r = 0; r < this.SIZE; r++) {
      for (let c = 0; c < this.SIZE; c++) {
        if (b[r][c] !== EMPTY) continue;
        const val = this.solution[r][c] === 0 ? SUN : MOON;
        const name = val === SUN ? 'diell' : 'hënë';

        // Check if this cell can be deduced by row count
        const rowSuns = b[r].filter(v => v === SUN).length;
        const rowMoons = b[r].filter(v => v === MOON).length;
        if (rowSuns === 3 || rowMoons === 3) {
          const newBoard = b.map(row => [...row]);
          newBoard[r][c] = val;
          this.history.push(b.map(row => [...row]));
          this.historyLength.set(this.history.length);
          this.board.set(newBoard);
          this.updateConflicts();
          this.hintCells.set([{ row: r, col: c }]);
          this.hintMessage.set(`Rreshti ${r + 1} ka tashmë 3 nga njëri lloj — vendos ${name}.`);
          this.scheduleHintClear();
          this.startHintCooldown();
          this.checkWin();
          return;
        }

        // Check column count
        let colSuns = 0, colMoons = 0;
        for (let r2 = 0; r2 < this.SIZE; r2++) {
          if (b[r2][c] === SUN) colSuns++;
          if (b[r2][c] === MOON) colMoons++;
        }
        if (colSuns === 3 || colMoons === 3) {
          const newBoard = b.map(row => [...row]);
          newBoard[r][c] = val;
          this.history.push(b.map(row => [...row]));
          this.historyLength.set(this.history.length);
          this.board.set(newBoard);
          this.updateConflicts();
          this.hintCells.set([{ row: r, col: c }]);
          this.hintMessage.set(`Kolona ${c + 1} ka tashmë 3 nga njëri lloj — vendos ${name}.`);
          this.scheduleHintClear();
          this.startHintCooldown();
          this.checkWin();
          return;
        }

        // Check consecutive constraint
        if (this.wouldCreateTriple(b, r, c, val === SUN ? (val === SUN ? MOON : SUN) : val)) {
          // The opposite would create a triple, so this must be the correct one
          continue; // skip, try next
        }
      }
    }

    // Step 3: Just reveal a random empty cell from solution
    const emptyCells: { row: number; col: number }[] = [];
    for (let r = 0; r < this.SIZE; r++) {
      for (let c = 0; c < this.SIZE; c++) {
        if (b[r][c] === EMPTY) emptyCells.push({ row: r, col: c });
      }
    }
    if (emptyCells.length > 0) {
      const cell = emptyCells[Math.floor(Math.random() * emptyCells.length)];
      const val = this.solution[cell.row][cell.col] === 0 ? SUN : MOON;
      const newBoard = b.map(row => [...row]);
      newBoard[cell.row][cell.col] = val;
      this.history.push(b.map(row => [...row]));
      this.historyLength.set(this.history.length);
      this.board.set(newBoard);
      this.updateConflicts();
      this.hintCells.set([cell]);
      this.hintMessage.set('Një simbol u vendos automatikisht.');
      this.scheduleHintClear();
      this.startHintCooldown();
      this.checkWin();
    } else {
      this.hintMessage.set('Tabela është plot — kontrollo zgjidhjen!');
      this.scheduleHintClear();
      this.startHintCooldown();
    }
  }

  private wouldCreateTriple(b: number[][], row: number, col: number, val: number): boolean {
    // Check horizontal triples
    if (col >= 2 && b[row][col - 1] === val && b[row][col - 2] === val) return true;
    if (col >= 1 && col < this.SIZE - 1 && b[row][col - 1] === val && b[row][col + 1] === val) return true;
    if (col < this.SIZE - 2 && b[row][col + 1] === val && b[row][col + 2] === val) return true;
    // Check vertical triples
    if (row >= 2 && b[row - 1][col] === val && b[row - 2][col] === val) return true;
    if (row >= 1 && row < this.SIZE - 1 && b[row - 1][col] === val && b[row + 1][col] === val) return true;
    if (row < this.SIZE - 2 && b[row + 1][col] === val && b[row + 2][col] === val) return true;
    return false;
  }

  private detectConflicts(b: number[][]): { row: number; col: number }[] {
    const conflicts = new Set<string>();

    for (let r = 0; r < this.SIZE; r++) {
      // Check row counts
      const rowSuns = b[r].filter(v => v === SUN).length;
      const rowMoons = b[r].filter(v => v === MOON).length;
      if (rowSuns > 3 || rowMoons > 3) {
        for (let c = 0; c < this.SIZE; c++) {
          if (b[r][c] !== EMPTY) conflicts.add(`${r},${c}`);
        }
      }

      // Check row consecutive (3 in a row)
      for (let c = 0; c <= this.SIZE - 3; c++) {
        if (b[r][c] !== EMPTY && b[r][c] === b[r][c + 1] && b[r][c] === b[r][c + 2]) {
          conflicts.add(`${r},${c}`);
          conflicts.add(`${r},${c + 1}`);
          conflicts.add(`${r},${c + 2}`);
        }
      }
    }

    for (let c = 0; c < this.SIZE; c++) {
      // Check column counts
      let colSuns = 0, colMoons = 0;
      for (let r = 0; r < this.SIZE; r++) {
        if (b[r][c] === SUN) colSuns++;
        if (b[r][c] === MOON) colMoons++;
      }
      if (colSuns > 3 || colMoons > 3) {
        for (let r = 0; r < this.SIZE; r++) {
          if (b[r][c] !== EMPTY) conflicts.add(`${r},${c}`);
        }
      }

      // Check column consecutive (3 in a column)
      for (let r = 0; r <= this.SIZE - 3; r++) {
        if (b[r][c] !== EMPTY && b[r][c] === b[r + 1][c] && b[r][c] === b[r + 2][c]) {
          conflicts.add(`${r},${c}`);
          conflicts.add(`${r + 1},${c}`);
          conflicts.add(`${r + 2},${c}`);
        }
      }
    }

    // Check constraint violations
    for (const ct of this.constraints) {
      const v1 = b[ct.r1][ct.c1];
      const v2 = b[ct.r2][ct.c2];
      if (v1 === EMPTY || v2 === EMPTY) continue;
      if (ct.type === 'same' && v1 !== v2) {
        conflicts.add(`${ct.r1},${ct.c1}`);
        conflicts.add(`${ct.r2},${ct.c2}`);
      }
      if (ct.type === 'diff' && v1 === v2) {
        conflicts.add(`${ct.r1},${ct.c1}`);
        conflicts.add(`${ct.r2},${ct.c2}`);
      }
    }

    return Array.from(conflicts).map(key => {
      const [r, c] = key.split(',').map(Number);
      return { row: r, col: c };
    });
  }

  private updateConflicts(): void {
    if (this.conflictTimeout) {
      clearTimeout(this.conflictTimeout);
      this.conflictTimeout = null;
    }

    const conflicts = this.detectConflicts(this.board());

    if (conflicts.length > 0) {
      this.conflictTimeout = setTimeout(() => {
        this.conflictCells.set(this.detectConflicts(this.board()));
        this.conflictTimeout = null;
      }, 2000);
    } else {
      this.conflictCells.set([]);
    }
  }

  private checkWin(): void {
    const b = this.board();

    // All cells must be filled
    for (let r = 0; r < this.SIZE; r++) {
      for (let c = 0; c < this.SIZE; c++) {
        if (b[r][c] === EMPTY) return;
      }
    }

    // No conflicts
    if (this.detectConflicts(b).length > 0) return;

    // Check each row has exactly 3 suns and 3 moons
    for (let r = 0; r < this.SIZE; r++) {
      const suns = b[r].filter(v => v === SUN).length;
      if (suns !== 3) return;
    }

    // Check each column has exactly 3 suns and 3 moons
    for (let c = 0; c < this.SIZE; c++) {
      let suns = 0;
      for (let r = 0; r < this.SIZE; r++) {
        if (b[r][c] === SUN) suns++;
      }
      if (suns !== 3) return;
    }

    // Check all constraints satisfied
    for (const ct of this.constraints) {
      const v1 = b[ct.r1][ct.c1];
      const v2 = b[ct.r2][ct.c2];
      if (ct.type === 'same' && v1 !== v2) return;
      if (ct.type === 'diff' && v1 === v2) return;
    }

    this.gameWon.set(true);
    this.stopTimer();
  }

  checkCorrect(): boolean {
    const b = this.board();
    for (let r = 0; r < this.SIZE; r++) {
      for (let c = 0; c < this.SIZE; c++) {
        if (b[r][c] === EMPTY) continue;
        const expected = this.solution[r][c] === 0 ? SUN : MOON;
        if (b[r][c] !== expected) return false;
      }
    }
    return true;
  }

  reset(): void {
    const b: number[][] = [];
    for (let r = 0; r < this.SIZE; r++) {
      const row: number[] = [];
      for (let c = 0; c < this.SIZE; c++) {
        const pf = this.prefilled[r][c];
        if (pf === 0) row.push(SUN);
        else if (pf === 1) row.push(MOON);
        else row.push(EMPTY);
      }
      b.push(row);
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

  getProgressSnapshot(): { board: number[][]; timerSeconds: number; history: number[][][] } | null {
    if (this.gameWon() || this.isRestored() || this.timerDisabled()) return null;
    const b = this.board();
    let hasMove = false;
    for (const row of b) {
      for (let c = 0; c < row.length; c++) {
        if (row[c] !== EMPTY && !this.isPrefilled(Math.floor(b.indexOf(row)), c)) {
          hasMove = true;
          break;
        }
      }
      if (hasMove) break;
    }
    if (!hasMove) return null;
    return {
      board: b.map(r => [...r]),
      timerSeconds: this.timerSeconds(),
      history: this.history.map(h => h.map(r => [...r])),
    };
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

  // Timer
  pauseTimer(): void { this.stopTimer(); }

  resumeTimer(): void {
    if (this.gameWon() || this.timerDisabled()) return;
    this.stopTimer();
    this.timerInterval = setInterval(() => {
      this.timerSeconds.update(v => v + 1);
    }, 1000);
  }

  private startTimer(): void {
    this.stopTimer();
    this.timerSeconds.set(0);
    this.hintCount.set(0);
    this.checkCount.set(0);
    this.timerInterval = setInterval(() => {
      this.timerSeconds.update(v => v + 1);
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
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

  private scheduleHintClear(): void {
    this.hintTimeout = setTimeout(() => {
      this.hintCells.set([]);
      this.hintMessage.set('');
      this.hintTimeout = null;
    }, 5000);
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
        if (this.hintCooldownInterval) {
          clearInterval(this.hintCooldownInterval);
          this.hintCooldownInterval = null;
        }
      }
    }, 1000);
  }

  private clearHint(): void {
    if (this.hintTimeout) {
      clearTimeout(this.hintTimeout);
      this.hintTimeout = null;
    }
    this.hintCells.set([]);
    this.hintMessage.set('');
    this.hintCooldown.set(false);
    this.hintCooldownRemaining.set(0);
    if (this.hintCooldownInterval) {
      clearInterval(this.hintCooldownInterval);
      this.hintCooldownInterval = null;
    }
  }

  destroy(): void {
    this.stopTimer();
    this.clearHint();
    if (this.conflictTimeout) {
      clearTimeout(this.conflictTimeout);
      this.conflictTimeout = null;
    }
  }
}
