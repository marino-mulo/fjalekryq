import { Injectable, signal, computed } from '@angular/core';
import { QueensPuzzle } from '../../core/models/queens-puzzle.model';

// Cell states
export const EMPTY = 0;
export const MARK_X = 1;   // Manually placed X
export const QUEEN = 2;
export const AUTO_X = 3;   // Auto-placed X (from queen row/col/diag)

@Injectable()
export class QueensGameService {
  // Puzzle data
  private size = 0;
  private zones: number[][] = [];
  private solution: number[] = [];

  // Reactive state
  readonly board = signal<number[][]>([]);
  readonly gameWon = signal(false);
  readonly timerSeconds = signal(0);
  readonly timerDisabled = signal(false);
  readonly isRestored = signal(false);

  // Conflict detection: cells whose queens are in conflict
  readonly conflictCells = signal<{ row: number; col: number }[]>([]);

  // Hint: cells to highlight + explanation message
  readonly hintCells = signal<{ row: number; col: number }[]>([]);
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  readonly checkCount = signal(0);
  private hintTimeout: ReturnType<typeof setTimeout> | null = null;
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;

  // Zone color names (Albanian) matching zoneColors order in board component
  private readonly zoneNames = [
    'e kuqe', 'portokalli', 'e verdhë', 'e gjelbër', 'mentë',
    'blu', 'indigo', 'vjollcë', 'rozë', 'pjeshkë', 'limoni'
  ];

  // Undo history — each entry is a snapshot of the board before an action
  private history: number[][][] = [];
  private readonly historyLength = signal(0);

  // Derived
  readonly queensCount = computed(() => {
    let count = 0;
    const b = this.board();
    for (const row of b) for (const cell of row) if (cell === QUEEN) count++;
    return count;
  });

  readonly canUndo = computed(() => this.historyLength() > 0 && !this.gameWon());
  readonly canHint = computed(() => !this.gameWon() && !this.hintCooldown());

  private timerInterval: ReturnType<typeof setInterval> | null = null;

  // Getters
  getSize() { return this.size; }
  getZones() { return this.zones; }
  getSolution() { return this.solution; }

  initPuzzle(puzzle: QueensPuzzle): void {
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

    // Create empty board
    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) {
      b.push(new Array(this.size).fill(EMPTY));
    }
    this.board.set(b);
    this.startTimer();
  }

  toggleCell(row: number, col: number): void {
    if (this.gameWon()) return;
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return;

    // Dismiss hint on user action
    this.clearHint();

    const b = this.board().map(r => [...r]);
    const current = b[row][col];

    // Save snapshot before change
    this.history.push(this.board().map(r => [...r]));
    this.historyLength.set(this.history.length);

    // Cycle: empty → X → queen → empty
    // AUTO_X cells also cycle: AUTO_X → queen → empty
    if (current === EMPTY) {
      b[row][col] = MARK_X;
    } else if (current === MARK_X || current === AUTO_X) {
      b[row][col] = QUEEN;
      // Auto-fill X marks around the queen
      this.autoFillXAroundQueen(b, row, col);
    } else {
      // Removing a queen — remove only AUTO_X marks, keep manual MARK_X
      b[row][col] = EMPTY;
      this.recalcAutoX(b);
    }

    this.board.set(b);
    this.updateConflicts();

    if (b[row][col] === QUEEN) {
      this.checkWin();
    }
  }

  /**
   * When a queen is placed, mark AUTO_X on:
   * - All cells in the same row (that are empty)
   * - All cells in the same column (that are empty)
   * - All cells in the same zone (that are empty)
   * - All 4 diagonal neighbor cells (that are empty)
   */
  private autoFillXAroundQueen(b: number[][], qRow: number, qCol: number): void {
    const n = this.size;

    // Same row
    for (let c = 0; c < n; c++) {
      if (c !== qCol && b[qRow][c] === EMPTY) {
        b[qRow][c] = AUTO_X;
      }
    }

    // Same column
    for (let r = 0; r < n; r++) {
      if (r !== qRow && b[r][qCol] === EMPTY) {
        b[r][qCol] = AUTO_X;
      }
    }

    // Same zone
    const queenZone = this.zones[qRow][qCol];
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (this.zones[r][c] === queenZone && !(r === qRow && c === qCol) && b[r][c] === EMPTY) {
          b[r][c] = AUTO_X;
        }
      }
    }

    // Diagonal neighbors (the 4 diagonal cells adjacent to queen)
    const diags = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    for (const [dr, dc] of diags) {
      const nr = qRow + dr;
      const nc = qCol + dc;
      if (nr >= 0 && nr < n && nc >= 0 && nc < n && b[nr][nc] === EMPTY) {
        b[nr][nc] = AUTO_X;
      }
    }
  }

  /**
   * Recalculate all AUTO_X marks from scratch.
   * Clears only AUTO_X cells, preserves manual MARK_X.
   * Then re-applies AUTO_X for all remaining queens.
   */
  private recalcAutoX(b: number[][]): void {
    const n = this.size;

    // Clear only auto-placed X marks
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === AUTO_X) {
          b[r][c] = EMPTY;
        }
      }
    }

    // Re-apply AUTO_X for all remaining queens
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === QUEEN) {
          this.autoFillXAroundQueen(b, r, c);
        }
      }
    }
  }

  undo(): void {
    if (this.history.length === 0 || this.gameWon()) return;
    const prev = this.history.pop()!;
    this.historyLength.set(this.history.length);
    this.board.set(prev);
    this.updateConflicts();
  }

  /**
   * Hint: first check for mistakes (wrong queens / X on solution cells),
   * auto-correct them, then find a logical deduction.
   */
  hint(): void {
    if (!this.canHint()) return;
    this.hintCount.update(v => v + 1);
    this.clearHint();

    const n = this.size;
    const b = this.board();

    // ── Step 1: Check for mistakes and auto-correct ──
    const corrections = this.correctMistakes(n, b);
    if (corrections) {
      this.history.push(b.map(r => [...r]));
      this.historyLength.set(this.history.length);
      this.board.set(corrections.board);
      this.updateConflicts();

      this.hintCells.set(corrections.cells);
      this.hintMessage.set(corrections.message);

      this.hintTimeout = setTimeout(() => {
        this.hintCells.set([]);
        this.hintMessage.set('');
        this.hintTimeout = null;
      }, 5000);

      this.startHintCooldown();
      return;
    }

    // ── Step 2: No mistakes — run deduction rules ──
    const solvedZones = new Set<number>();
    const solvedRows = new Set<number>();
    const solvedCols = new Set<number>();
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === QUEEN) {
          solvedZones.add(this.zones[r][c]);
          solvedRows.add(r);
          solvedCols.add(c);
        }
      }
    }

    const isAvailable = (r: number, c: number): boolean =>
      b[r][c] === EMPTY && !solvedRows.has(r) && !solvedCols.has(c) && !solvedZones.has(this.zones[r][c]);

    let result = this.ruleZoneConfinedToRow(n, b, solvedZones, isAvailable);
    if (!result) result = this.ruleZoneConfinedToCol(n, b, solvedZones, isAvailable);
    if (!result) result = this.ruleRowHasOneZone(n, b, solvedZones, solvedRows, isAvailable);
    if (!result) result = this.ruleColHasOneZone(n, b, solvedZones, solvedCols, isAvailable);
    if (!result) result = this.ruleZoneOneCell(n, b, solvedZones, isAvailable);
    if (!result) result = this.ruleConflictElimination(n, b, solvedZones, isAvailable);

    if (!result || result.cells.length === 0) {
      this.hintMessage.set('Nuk gjeta ndihmë — provo të analizosh zonat me pak hapësirë.');
      this.hintTimeout = setTimeout(() => {
        this.hintMessage.set('');
      }, 4000);
      this.startHintCooldown();
      return;
    }

    this.history.push(this.board().map(r => [...r]));
    this.historyLength.set(this.history.length);

    const newBoard = b.map(r => [...r]);
    for (const cell of result.cells) {
      if (newBoard[cell.row][cell.col] === EMPTY) {
        newBoard[cell.row][cell.col] = AUTO_X;
      }
    }
    this.board.set(newBoard);

    this.hintCells.set(result.cells);
    this.hintMessage.set(result.message);

    this.hintTimeout = setTimeout(() => {
      this.hintCells.set([]);
      this.hintMessage.set('');
      this.hintTimeout = null;
    }, 5000);

    this.startHintCooldown();
  }

  /**
   * Check the board against the solution for mistakes:
   * 1. A queen placed in a wrong position (not matching solution[row])
   * 2. An X/MARK_X placed where a queen should go (solution cell blocked)
   * Returns a corrected board + message, or null if no mistakes.
   */
  private correctMistakes(n: number, b: number[][]): {
    board: number[][];
    cells: { row: number; col: number }[];
    message: string;
  } | null {
    const newBoard = b.map(r => [...r]);

    // Find the FIRST mistake only (one at a time)
    for (let r = 0; r < n; r++) {
      const correctCol = this.solution[r];

      // Check for wrong queens in this row
      for (let c = 0; c < n; c++) {
        if (newBoard[r][c] === QUEEN && c !== correctCol) {
          newBoard[r][c] = EMPTY;
          this.recalcAutoX(newBoard);
          return {
            board: newBoard,
            cells: [{ row: r, col: c }],
            message: '1 mbretëreshë e gabuar u hoq — tani provo përsëri!'
          };
        }
      }

      // Check if the correct solution cell is blocked by X
      if (newBoard[r][correctCol] === MARK_X || newBoard[r][correctCol] === AUTO_X) {
        newBoard[r][correctCol] = EMPTY;
        this.recalcAutoX(newBoard);
        return {
          board: newBoard,
          cells: [{ row: r, col: correctCol }],
          message: '1 X e gabuar u fshi — tani provo përsëri!'
        };
      }
    }

    return null;
  }

  private zoneName(z: number): string {
    return this.zoneNames[z % this.zoneNames.length];
  }

  /**
   * Rule 1a: If an unsolved zone's available cells all lie in a single row,
   * then that row belongs to this zone → X all other zones' empty cells in that row.
   */
  private ruleZoneConfinedToRow(
    n: number, b: number[][], solvedZones: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let z = 0; z < n; z++) {
      if (solvedZones.has(z)) continue;
      const rows = new Set<number>();
      for (let r = 0; r < n; r++) {
        for (let c = 0; c < n; c++) {
          if (this.zones[r][c] === z && isAvailable(r, c)) rows.add(r);
        }
      }
      if (rows.size === 1) {
        const row = rows.values().next().value!;
        const cells: { row: number; col: number }[] = [];
        for (let c = 0; c < n; c++) {
          if (this.zones[row][c] !== z && b[row][c] === EMPTY) {
            cells.push({ row, col: c });
          }
        }
        if (cells.length > 0) {
          return {
            cells,
            message: `Zona ${this.zoneName(z)} mund të jetë vetëm në rreshtin ${row + 1} — X në qelizat e tjera.`
          };
        }
      }
    }
    return null;
  }

  /**
   * Rule 1b: Same logic but for columns.
   */
  private ruleZoneConfinedToCol(
    n: number, b: number[][], solvedZones: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let z = 0; z < n; z++) {
      if (solvedZones.has(z)) continue;
      const cols = new Set<number>();
      for (let r = 0; r < n; r++) {
        for (let c = 0; c < n; c++) {
          if (this.zones[r][c] === z && isAvailable(r, c)) cols.add(c);
        }
      }
      if (cols.size === 1) {
        const col = cols.values().next().value!;
        const cells: { row: number; col: number }[] = [];
        for (let r = 0; r < n; r++) {
          if (this.zones[r][col] !== z && b[r][col] === EMPTY) {
            cells.push({ row: r, col });
          }
        }
        if (cells.length > 0) {
          return {
            cells,
            message: `Zona ${this.zoneName(z)} mund të jetë vetëm në kolonën ${col + 1} — X në qelizat e tjera.`
          };
        }
      }
    }
    return null;
  }

  /**
   * Rule 2a: If a row has only one unsolved zone with available cells,
   * that zone's queen must be in this row → X that zone's cells in other rows.
   */
  private ruleRowHasOneZone(
    n: number, b: number[][], solvedZones: Set<number>, solvedRows: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let r = 0; r < n; r++) {
      if (solvedRows.has(r)) continue;
      const zonesInRow = new Set<number>();
      for (let c = 0; c < n; c++) {
        if (isAvailable(r, c)) zonesInRow.add(this.zones[r][c]);
      }
      if (zonesInRow.size === 1) {
        const zone = zonesInRow.values().next().value!;
        // X all cells of this zone in OTHER rows
        const cells: { row: number; col: number }[] = [];
        for (let r2 = 0; r2 < n; r2++) {
          if (r2 === r) continue;
          for (let c = 0; c < n; c++) {
            if (this.zones[r2][c] === zone && b[r2][c] === EMPTY) {
              cells.push({ row: r2, col: c });
            }
          }
        }
        if (cells.length > 0) {
          return {
            cells,
            message: `Rreshti ${r + 1} ka vetëm zonën ${this.zoneName(zone)} — X në pjesën tjetër të zonës.`
          };
        }
      }
    }
    return null;
  }

  /**
   * Rule 2b: Same logic but for columns.
   */
  private ruleColHasOneZone(
    n: number, b: number[][], solvedZones: Set<number>, solvedCols: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let c = 0; c < n; c++) {
      if (solvedCols.has(c)) continue;
      const zonesInCol = new Set<number>();
      for (let r = 0; r < n; r++) {
        if (isAvailable(r, c)) zonesInCol.add(this.zones[r][c]);
      }
      if (zonesInCol.size === 1) {
        const zone = zonesInCol.values().next().value!;
        const cells: { row: number; col: number }[] = [];
        for (let c2 = 0; c2 < n; c2++) {
          if (c2 === c) continue;
          for (let r = 0; r < n; r++) {
            if (this.zones[r][c2] === zone && b[r][c2] === EMPTY) {
              cells.push({ row: r, col: c2 });
            }
          }
        }
        if (cells.length > 0) {
          return {
            cells,
            message: `Kolona ${c + 1} ka vetëm zonën ${this.zoneName(zone)} — X në pjesën tjetër të zonës.`
          };
        }
      }
    }
    return null;
  }

  /**
   * Rule 3: If a zone has only one available cell, X all conflicting cells
   * (same row, same col, diagonal neighbors) since the queen must go there.
   */
  private ruleZoneOneCell(
    n: number, b: number[][], solvedZones: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let z = 0; z < n; z++) {
      if (solvedZones.has(z)) continue;
      const available: { row: number; col: number }[] = [];
      for (let r = 0; r < n; r++) {
        for (let c = 0; c < n; c++) {
          if (this.zones[r][c] === z && isAvailable(r, c)) available.push({ row: r, col: c });
        }
      }
      if (available.length === 1) {
        const qr = available[0].row;
        const qc = available[0].col;
        const cells: { row: number; col: number }[] = [];
        // Same row
        for (let c = 0; c < n; c++) {
          if (c !== qc && b[qr][c] === EMPTY) cells.push({ row: qr, col: c });
        }
        // Same col
        for (let r = 0; r < n; r++) {
          if (r !== qr && b[r][qc] === EMPTY) cells.push({ row: r, col: qc });
        }
        // Diagonal neighbors
        for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
          const nr = qr + dr, nc = qc + dc;
          if (nr >= 0 && nr < n && nc >= 0 && nc < n && b[nr][nc] === EMPTY) {
            cells.push({ row: nr, col: nc });
          }
        }
        if (cells.length > 0) {
          return {
            cells,
            message: `Zona ${this.zoneName(z)} ka vetëm një qelizë të lirë (${qr + 1},${qc + 1}) — X rreth saj.`
          };
        }
      }
    }
    return null;
  }

  /**
   * Rule 4: If placing a queen at a cell would leave another zone with zero
   * available cells, that cell must be X.
   */
  private ruleConflictElimination(
    n: number, b: number[][], solvedZones: Set<number>,
    isAvailable: (r: number, c: number) => boolean
  ): { cells: { row: number; col: number }[]; message: string } | null {
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (!isAvailable(r, c)) continue;
        const cellZone = this.zones[r][c];

        // Simulate placing queen at (r,c): which cells become blocked?
        for (let z = 0; z < n; z++) {
          if (solvedZones.has(z) || z === cellZone) continue;
          // Check if zone z would have any available cells left
          let hasAvailable = false;
          for (let r2 = 0; r2 < n && !hasAvailable; r2++) {
            for (let c2 = 0; c2 < n && !hasAvailable; c2++) {
              if (this.zones[r2][c2] !== z) continue;
              if (!isAvailable(r2, c2)) continue;
              // Would this cell be blocked by a queen at (r,c)?
              if (r2 === r || c2 === c) continue; // same row/col blocked
              if (Math.abs(r2 - r) <= 1 && Math.abs(c2 - c) <= 1) continue; // diagonal blocked
              hasAvailable = true;
            }
          }
          if (!hasAvailable) {
            return {
              cells: [{ row: r, col: c }],
              message: `Mbretëresha këtu do të bllokonte zonën ${this.zoneName(z)} — vendos X.`
            };
          }
        }
      }
    }
    return null;
  }

  /**
   * Detect conflicts between queens:
   * - Same row, same column, same zone, or diagonally adjacent.
   * Returns all queen cells involved in at least one conflict.
   */
  private detectConflicts(b: number[][]): { row: number; col: number }[] {
    const n = this.size;
    const queens: { row: number; col: number }[] = [];
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === QUEEN) queens.push({ row: r, col: c });
      }
    }

    if (queens.length < 2) return [];

    const conflictSet = new Set<string>();
    for (let i = 0; i < queens.length; i++) {
      for (let j = i + 1; j < queens.length; j++) {
        const a = queens[i];
        const bq = queens[j];
        const sameRow = a.row === bq.row;
        const sameCol = a.col === bq.col;
        const sameZone = this.zones[a.row][a.col] === this.zones[bq.row][bq.col];
        const diagTouch = Math.abs(a.row - bq.row) <= 1 && Math.abs(a.col - bq.col) <= 1;

        if (sameRow || sameCol || sameZone || diagTouch) {
          conflictSet.add(`${a.row},${a.col}`);
          conflictSet.add(`${bq.row},${bq.col}`);
        }
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

    // Must have exactly N queens
    let queenCount = 0;
    const queenPositions: [number, number][] = [];
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] === QUEEN) {
          queenCount++;
          queenPositions.push([r, c]);
        }
      }
    }
    if (queenCount !== n) return;

    // 1 queen per row
    const rowSet = new Set(queenPositions.map(([r]) => r));
    if (rowSet.size !== n) return;

    // 1 queen per column
    const colSet = new Set(queenPositions.map(([, c]) => c));
    if (colSet.size !== n) return;

    // 1 queen per zone
    const zoneSet = new Set(queenPositions.map(([r, c]) => this.zones[r][c]));
    if (zoneSet.size !== n) return;

    // No two queens touching (including diagonal)
    for (let i = 0; i < queenPositions.length; i++) {
      for (let j = i + 1; j < queenPositions.length; j++) {
        const [r1, c1] = queenPositions[i];
        const [r2, c2] = queenPositions[j];
        if (Math.abs(r1 - r2) <= 1 && Math.abs(c1 - c2) <= 1) {
          return; // touching!
        }
      }
    }

    this.gameWon.set(true);
    this.stopTimer();
  }

  reset(): void {
    const b: number[][] = [];
    for (let r = 0; r < this.size; r++) {
      b.push(new Array(this.size).fill(EMPTY));
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

  /** Get snapshot of current in-progress state for persistence */
  getProgressSnapshot(): { board: number[][]; timerSeconds: number; history: number[][][] } | null {
    if (this.gameWon() || this.isRestored() || this.timerDisabled()) return null;
    const b = this.board();
    let hasMove = false;
    for (const row of b) {
      for (const cell of row) {
        if (cell !== EMPTY) { hasMove = true; break; }
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

  /** Restore a paused in-progress state */
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

  /**
   * Check if the current board has any errors.
   * Returns true if everything is correct so far, false if there's an error.
   * Does NOT reveal where the error is.
   */
  checkCorrect(): boolean {
    const n = this.size;
    const b = this.board();
    for (let r = 0; r < n; r++) {
      const correctCol = this.solution[r];
      for (let c = 0; c < n; c++) {
        // Wrong queen
        if (b[r][c] === QUEEN && c !== correctCol) return false;
      }
      // X blocking the solution cell
      if (b[r][correctCol] === MARK_X) return false;
    }
    return true;
  }

  /** Pause the timer (e.g. when leaving page) */
  pauseTimer(): void {
    this.stopTimer();
  }

  /** Resume the timer (e.g. when returning to page) */
  resumeTimer(): void {
    if (this.gameWon() || this.timerDisabled()) return;
    this.stopTimer();
    this.timerInterval = setInterval(() => {
      this.timerSeconds.update(v => v + 1);
    }, 1000);
  }

  // Timer
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
  }
}
