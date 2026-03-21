import { Injectable, signal, computed } from '@angular/core';
import { StarsPuzzle } from '../../core/models/stars-puzzle.model';

export const EMPTY = 0;
export const MARK_X = 1;
export const STAR = 2;
export const AUTO_X = 3;

@Injectable()
export class StarsGameService {
  private size = 0;
  private zones: number[][] = [];
  private solution: number[][] = []; // solution[row] = [col1, col2]

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

  private readonly zoneNames = [
    'e kuqe', 'portokalli', 'e verdhë', 'e gjelbër', 'mentë',
    'blu', 'indigo', 'vjollcë', 'rozë', 'pjeshkë', 'limoni', 'moçaliku'
  ];

  private history: number[][][] = [];
  private readonly historyLength = signal(0);

  readonly starsCount = computed(() => {
    let count = 0;
    for (const row of this.board()) for (const cell of row) if (cell === STAR) count++;
    return count;
  });

  readonly canUndo = computed(() => this.historyLength() > 0 && !this.gameWon());
  readonly canHint = computed(() => !this.gameWon() && !this.hintCooldown());

  getSize() { return this.size; }
  getZones() { return this.zones; }
  getSolution() { return this.solution; }

  initPuzzle(puzzle: StarsPuzzle): void {
    this.size = puzzle.size;
    this.zones = puzzle.zones;
    this.solution = puzzle.solution;
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.history = [];
    this.historyLength.set(0);
    this.clearHint();
    this.conflictCells.set([]);

    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) b.push(new Array(this.size).fill(EMPTY));
    this.board.set(b);
    this.startTimer();
  }

  toggleCell(row: number, col: number): void {
    if (this.gameWon()) return;
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return;

    this.clearHint();
    const b = this.board().map(r => [...r]);
    const current = b[row][col];

    this.history.push(this.board().map(r => [...r]));
    this.historyLength.set(this.history.length);

    if (current === EMPTY) {
      b[row][col] = MARK_X;
    } else if (current === MARK_X || current === AUTO_X) {
      b[row][col] = STAR;
    } else {
      b[row][col] = EMPTY;
    }

    this.board.set(b);
    this.updateConflicts();

    if (b[row][col] === STAR) this.checkWin();
  }

  /**
   * When a star is placed at (row, col):
   * - Always X all 8 neighbors (no adjacency allowed, including diagonals)
   * - If this row now has 2 stars → X all remaining empty cells in row
   * - If this col now has 2 stars → X all remaining empty cells in col
   * - If this zone now has 2 stars → X all remaining empty cells in zone
   */
  private autoFillXAroundStar(b: number[][], qRow: number, qCol: number): void {
    const n = this.size;

    // All 8 neighbors always get X (no two stars can touch)
    for (const [dr, dc] of [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]) {
      const nr = qRow + dr, nc = qCol + dc;
      if (nr >= 0 && nr < n && nc >= 0 && nc < n && b[nr][nc] === EMPTY) {
        b[nr][nc] = AUTO_X;
      }
    }

    // Count stars in this row
    const rowStars = this.countStarsInRow(b, qRow);
    if (rowStars >= 2) {
      for (let c = 0; c < n; c++) {
        if (b[qRow][c] === EMPTY) b[qRow][c] = AUTO_X;
      }
    }

    // Count stars in this col
    const colStars = this.countStarsInCol(b, qCol);
    if (colStars >= 2) {
      for (let r = 0; r < n; r++) {
        if (b[r][qCol] === EMPTY) b[r][qCol] = AUTO_X;
      }
    }

    // Count stars in this zone
    const zone = this.zones[qRow][qCol];
    const zoneStars = this.countStarsInZone(b, zone);
    if (zoneStars >= 2) {
      for (let r = 0; r < n; r++) {
        for (let c = 0; c < n; c++) {
          if (this.zones[r][c] === zone && b[r][c] === EMPTY) {
            b[r][c] = AUTO_X;
          }
        }
      }
    }
  }

  private recalcAutoX(b: number[][]): void {
    const n = this.size;
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (b[r][c] === AUTO_X) b[r][c] = EMPTY;

    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (b[r][c] === STAR) this.autoFillXAroundStar(b, r, c);
  }

  private countStarsInRow(b: number[][], row: number): number {
    let count = 0;
    for (let c = 0; c < this.size; c++) if (b[row][c] === STAR) count++;
    return count;
  }

  private countStarsInCol(b: number[][], col: number): number {
    let count = 0;
    for (let r = 0; r < this.size; r++) if (b[r][col] === STAR) count++;
    return count;
  }

  private countStarsInZone(b: number[][], zone: number): number {
    let count = 0;
    for (let r = 0; r < this.size; r++)
      for (let c = 0; c < this.size; c++)
        if (this.zones[r][c] === zone && b[r][c] === STAR) count++;
    return count;
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

    const n = this.size;
    const b = this.board();

    // Step 1: Check for wrong stars (stars not in solution) — remove one
    for (let r = 0; r < n; r++) {
      const solCols = new Set(this.solution[r]);
      for (let c = 0; c < n; c++) {
        if (b[r][c] === STAR && !solCols.has(c)) {
          this.history.push(b.map(row => [...row]));
          this.historyLength.set(this.history.length);

          const nb = b.map(row => [...row]);
          nb[r][c] = EMPTY;
          this.recalcAutoX(nb);
          this.board.set(nb);
          this.updateConflicts();

          this.hintCells.set([{ row: r, col: c }]);
          this.hintMessage.set('1 yll i gabuar u hoq!');
          this.scheduleHintClear();
          this.startHintCooldown();
          return;
        }
      }
    }

    // Step 2: No wrong stars — place a correct star
    const unplaced: { row: number; col: number }[] = [];
    for (let r = 0; r < n; r++) {
      for (const c of this.solution[r]) {
        if (b[r][c] !== STAR) {
          unplaced.push({ row: r, col: c });
        }
      }
    }

    if (unplaced.length === 0) return;

    // Pick a random unplaced star
    const target = unplaced[Math.floor(Math.random() * unplaced.length)];

    this.history.push(b.map(r => [...r]));
    this.historyLength.set(this.history.length);

    const nb = b.map(r => [...r]);
    nb[target.row][target.col] = STAR;
    this.autoFillXAroundStar(nb, target.row, target.col);
    this.board.set(nb);
    this.updateConflicts();

    this.hintCells.set([target]);
    this.hintMessage.set('1 yll u vendos në vendin e duhur!');
    this.scheduleHintClear();
    this.startHintCooldown();
    this.checkWin();
  }

  /** Auto-X cells adjacent to stars + cells in full rows/cols/zones */
  private findAutoX(n: number, b: number[][], dirs: number[][]): { board: number[][]; message: string } | null {
    const nb = b.map(r => [...r]);
    let count = 0;

    // X all 8 neighbors of every star
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] !== STAR) continue;
        for (const [dr, dc] of dirs) {
          const nr = r + dr, nc = c + dc;
          if (nr >= 0 && nr < n && nc >= 0 && nc < n && nb[nr][nc] === EMPTY) {
            nb[nr][nc] = AUTO_X; count++;
          }
        }
      }
    }

    // X remaining cells in rows with 2 stars
    for (let r = 0; r < n; r++) {
      if (this.countStarsInRow(nb, r) >= 2) {
        for (let c = 0; c < n; c++) {
          if (nb[r][c] === EMPTY) { nb[r][c] = AUTO_X; count++; }
        }
      }
    }

    // X remaining cells in cols with 2 stars
    for (let c = 0; c < n; c++) {
      if (this.countStarsInCol(nb, c) >= 2) {
        for (let r = 0; r < n; r++) {
          if (nb[r][c] === EMPTY) { nb[r][c] = AUTO_X; count++; }
        }
      }
    }

    // X remaining cells in zones with 2 stars
    for (let z = 0; z < n; z++) {
      if (this.countStarsInZone(nb, z) >= 2) {
        for (let r = 0; r < n; r++) {
          for (let c = 0; c < n; c++) {
            if (this.zones[r][c] === z && nb[r][c] === EMPTY) { nb[r][c] = AUTO_X; count++; }
          }
        }
      }
    }

    return count > 0 ? { board: nb, message: `${count} qeliza u shënuan me X.` } : null;
  }

  /** Find forced placements: zone/row/col with exactly `needed` available cells → X neighbors */
  private findForcedElimination(n: number, b: number[][], dirs: number[][]): { board: number[][]; message: string } | null {
    const isAvailable = (r: number, c: number): boolean => {
      if (b[r][c] !== EMPTY) return false;
      if (this.countStarsInRow(b, r) >= 2) return false;
      if (this.countStarsInCol(b, c) >= 2) return false;
      if (this.countStarsInZone(b, this.zones[r][c]) >= 2) return false;
      for (const [dr, dc] of dirs) {
        const nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n && b[nr][nc] === STAR) return false;
      }
      return true;
    };

    const xNeighbors = (available: { row: number; col: number }[]): { board: number[][]; count: number } => {
      const nb = b.map(r => [...r]);
      let count = 0;
      for (const { row: qr, col: qc } of available) {
        for (const [dr, dc] of dirs) {
          const nr = qr + dr, nc = qc + dc;
          if (nr >= 0 && nr < n && nc >= 0 && nc < n && nb[nr][nc] === EMPTY
            && !available.some(a => a.row === nr && a.col === nc)) {
            nb[nr][nc] = AUTO_X; count++;
          }
        }
      }
      return { board: nb, count };
    };

    // Check zones
    for (let z = 0; z < n; z++) {
      const zStars = this.countStarsInZone(b, z);
      if (zStars >= 2) continue;
      const needed = 2 - zStars;
      const available: { row: number; col: number }[] = [];
      for (let r = 0; r < n; r++)
        for (let c = 0; c < n; c++)
          if (this.zones[r][c] === z && isAvailable(r, c)) available.push({ row: r, col: c });
      if (available.length === needed && needed > 0) {
        const { board, count } = xNeighbors(available);
        if (count > 0) return {
          board,
          message: `Zona ${this.zoneName(z)} ka vetëm ${needed === 1 ? '1 vend' : needed + ' vende'} — X rreth tyre.`
        };
      }
    }

    // Check rows
    for (let r = 0; r < n; r++) {
      const rStars = this.countStarsInRow(b, r);
      if (rStars >= 2) continue;
      const needed = 2 - rStars;
      const available: { row: number; col: number }[] = [];
      for (let c = 0; c < n; c++)
        if (isAvailable(r, c)) available.push({ row: r, col: c });
      if (available.length === needed && needed > 0) {
        const { board, count } = xNeighbors(available);
        if (count > 0) return {
          board,
          message: `Rreshti ${r + 1} ka vetëm ${needed === 1 ? '1 vend' : needed + ' vende'} — X rreth tyre.`
        };
      }
    }

    // Check cols
    for (let c = 0; c < n; c++) {
      const cStars = this.countStarsInCol(b, c);
      if (cStars >= 2) continue;
      const needed = 2 - cStars;
      const available: { row: number; col: number }[] = [];
      for (let r = 0; r < n; r++)
        if (isAvailable(r, c)) available.push({ row: r, col: c });
      if (available.length === needed && needed > 0) {
        const { board, count } = xNeighbors(available);
        if (count > 0) return {
          board,
          message: `Kolona ${c + 1} ka vetëm ${needed === 1 ? '1 vend' : needed + ' vende'} — X rreth tyre.`
        };
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

  private correctMistakes(n: number, b: number[][]): {
    board: number[][];
    cells: { row: number; col: number }[];
    message: string;
  } | null {
    const newBoard = b.map(r => [...r]);
    for (let r = 0; r < n; r++) {
      const solCols = new Set(this.solution[r]);
      for (let c = 0; c < n; c++) {
        if (newBoard[r][c] === STAR && !solCols.has(c)) {
          newBoard[r][c] = EMPTY;
          this.recalcAutoX(newBoard);
          return { board: newBoard, cells: [{ row: r, col: c }], message: '1 yll i gabuar u hoq — tani provo përsëri!' };
        }
      }
      for (const sc of solCols) {
        if (newBoard[r][sc] === MARK_X || newBoard[r][sc] === AUTO_X) {
          newBoard[r][sc] = EMPTY;
          this.recalcAutoX(newBoard);
          return { board: newBoard, cells: [{ row: r, col: sc }], message: '1 X e gabuar u fshi — tani provo përsëri!' };
        }
      }
    }
    return null;
  }

  private zoneName(z: number): string {
    return this.zoneNames[z % this.zoneNames.length];
  }

  private detectConflicts(b: number[][]): { row: number; col: number }[] {
    const n = this.size;
    const stars: { row: number; col: number }[] = [];
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (b[r][c] === STAR) stars.push({ row: r, col: c });

    if (stars.length < 2) return [];

    const conflictSet = new Set<string>();
    for (let i = 0; i < stars.length; i++) {
      for (let j = i + 1; j < stars.length; j++) {
        const a = stars[i], bq = stars[j];
        // Adjacency: any two stars touching (including diagonals) is a conflict
        const touching = Math.abs(a.row - bq.row) <= 1 && Math.abs(a.col - bq.col) <= 1;
        if (touching) {
          conflictSet.add(`${a.row},${a.col}`);
          conflictSet.add(`${bq.row},${bq.col}`);
        }
      }
    }

    // Also flag rows/cols/zones with >2 stars
    const rowCounts = new Map<number, number>();
    const colCounts = new Map<number, number>();
    const zoneCounts = new Map<number, number>();
    for (const { row, col } of stars) {
      rowCounts.set(row, (rowCounts.get(row) ?? 0) + 1);
      colCounts.set(col, (colCounts.get(col) ?? 0) + 1);
      const z = this.zones[row][col];
      zoneCounts.set(z, (zoneCounts.get(z) ?? 0) + 1);
    }
    for (const { row, col } of stars) {
      if ((rowCounts.get(row) ?? 0) > 2 || (colCounts.get(col) ?? 0) > 2
        || (zoneCounts.get(this.zones[row][col]) ?? 0) > 2) {
        conflictSet.add(`${row},${col}`);
      }
    }

    return Array.from(conflictSet).map(key => {
      const [r, c] = key.split(',').map(Number);
      return { row: r, col: c };
    });
  }

  private updateConflicts(): void {
    this.conflictCells.set(this.detectConflicts(this.board()));
  }

  private checkWin(): void {
    const b = this.board();
    const n = this.size;

    const stars: [number, number][] = [];
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (b[r][c] === STAR) stars.push([r, c]);

    if (stars.length !== 2 * n) return;

    // 2 per row
    const rowCounts = new Array(n).fill(0);
    const colCounts = new Array(n).fill(0);
    const zoneCounts = new Array(n).fill(0);
    for (const [r, c] of stars) {
      rowCounts[r]++;
      colCounts[c]++;
      zoneCounts[this.zones[r][c]]++;
    }
    for (let i = 0; i < n; i++) {
      if (rowCounts[i] !== 2 || colCounts[i] !== 2 || zoneCounts[i] !== 2) return;
    }

    // No two stars touching (including diagonal)
    for (let i = 0; i < stars.length; i++) {
      for (let j = i + 1; j < stars.length; j++) {
        const [r1, c1] = stars[i], [r2, c2] = stars[j];
        if (Math.abs(r1 - r2) <= 1 && Math.abs(c1 - c2) <= 1) return;
      }
    }

    // Auto-fill remaining empty cells with X
    const filled = b.map(r => [...r]);
    for (let r = 0; r < n; r++)
      for (let c = 0; c < n; c++)
        if (filled[r][c] === EMPTY || filled[r][c] === AUTO_X) filled[r][c] = MARK_X;
    this.board.set(filled);

    this.gameWon.set(true);
    this.stopTimer();
  }

  checkCorrect(): boolean {
    const n = this.size;
    const b = this.board();
    for (let r = 0; r < n; r++) {
      const solCols = new Set(this.solution[r]);
      for (let c = 0; c < n; c++) {
        if (b[r][c] === STAR && !solCols.has(c)) return false;
      }
      for (const sc of solCols) {
        if (b[r][sc] === MARK_X) return false;
      }
    }
    return true;
  }

  reset(): void {
    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) b.push(new Array(this.size).fill(EMPTY));
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
    this.hintCooldownRemaining.set(10);
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
