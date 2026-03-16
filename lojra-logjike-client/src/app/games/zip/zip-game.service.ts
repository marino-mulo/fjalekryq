import { Injectable, signal, computed } from '@angular/core';
import { ZipPuzzle } from '../../core/models/zip-puzzle.model';

export interface Checkpoint {
  value: number;
  index: number;
}

@Injectable()
export class ZipGameService {
  // Puzzle data
  private rows = 0;
  private cols = 0;
  private totalCells = 0;
  private numberMap: Record<number, number> = {};
  private wallSet = new Set<string>();
  private wallPairs: number[][] = [];
  private checkpoints: Checkpoint[] = [];
  private solutionPath: number[] = [];

  // Reactive state
  readonly path = signal<number[]>([]);
  readonly gameWon = signal(false);
  readonly timerSeconds = signal(0);
  readonly timerDisabled = signal(false);
  readonly isRestored = signal(false); // true when showing a previously completed game

  // Hint state
  readonly hintMessage = signal('');
  readonly hintCooldown = signal(false);
  readonly hintCooldownRemaining = signal(0);
  readonly hintCount = signal(0);
  private hintCooldownInterval: ReturnType<typeof setInterval> | null = null;
  private hintMessageTimer: ReturnType<typeof setTimeout> | null = null;

  // Derived
  readonly pathSet = computed(() => new Set(this.path()));
  readonly progress = computed(() => this.totalCells > 0 ? Math.round((this.path().length / this.totalCells) * 100) : 0);
  readonly currentHead = computed(() => { const p = this.path(); return p.length > 0 ? p[p.length - 1] : -1; });
  readonly canUndo = computed(() => this.path().length > 1 && !this.gameWon());
  readonly canHint = computed(() => !this.gameWon() && !this.hintCooldown() && this.path().length < this.totalCells && this.solutionPath.length > 0);

  private timerInterval: ReturnType<typeof setInterval> | null = null;

  // Getters
  getRows() { return this.rows; }
  getCols() { return this.cols; }
  getTotalCells() { return this.totalCells; }
  getNumberMap() { return this.numberMap; }
  getCheckpoints() { return this.checkpoints; }
  getWallPairs() { return this.wallPairs; }

  initPuzzle(puzzle: ZipPuzzle): void {
    this.rows = puzzle.rows;
    this.cols = puzzle.cols;
    this.totalCells = this.rows * this.cols;
    this.solutionPath = puzzle.solutionPath ?? [];
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.clearHintState();

    // Build number map
    this.numberMap = {};
    this.checkpoints = [];
    for (const [idx, val] of Object.entries(puzzle.numbers)) {
      this.numberMap[Number(idx)] = val;
      this.checkpoints.push({ value: val, index: Number(idx) });
    }
    this.checkpoints.sort((a, b) => a.value - b.value);

    // Build wall set and store raw pairs
    this.wallSet.clear();
    this.wallPairs = puzzle.walls.map(w => [...w]);
    for (const w of puzzle.walls) {
      this.wallSet.add(`${w[0]},${w[1]}>${w[2]},${w[3]}`);
    }

    // Start path at checkpoint 1
    this.path.set([this.checkpoints[0].index]);
    this.startTimer();
  }

  // Grid helpers
  rc(index: number): [number, number] {
    return [Math.floor(index / this.cols), index % this.cols];
  }

  idx(r: number, c: number): number {
    return r * this.cols + c;
  }

  isAdjacent(a: number, b: number): boolean {
    const [r1, c1] = this.rc(a);
    const [r2, c2] = this.rc(b);
    return (Math.abs(r1 - r2) + Math.abs(c1 - c2)) === 1;
  }

  hasWall(a: number, b: number): boolean {
    const [r1, c1] = this.rc(a);
    const [r2, c2] = this.rc(b);
    return this.wallSet.has(`${r1},${c1}>${r2},${c2}`) || this.wallSet.has(`${r2},${c2}>${r1},${c1}`);
  }

  wallsForCell(r: number, c: number): { top: boolean; bottom: boolean; left: boolean; right: boolean } {
    const result = { top: false, bottom: false, left: false, right: false };
    for (const wStr of this.wallSet) {
      const parts = wStr.split('>');
      const [r1, c1] = parts[0].split(',').map(Number);
      const [r2, c2] = parts[1].split(',').map(Number);
      if (r1 === r && c1 === c) {
        if (r2 === r + 1 && c2 === c) result.bottom = true;
        if (r2 === r && c2 === c + 1) result.right = true;
        if (r2 === r - 1 && c2 === c) result.top = true;
        if (r2 === r && c2 === c - 1) result.left = true;
      }
      if (r2 === r && c2 === c) {
        if (r1 === r + 1 && c1 === c) result.bottom = true;
        if (r1 === r && c1 === c + 1) result.right = true;
        if (r1 === r - 1 && c1 === c) result.top = true;
        if (r1 === r && c1 === c - 1) result.left = true;
      }
    }
    return result;
  }

  canMoveTo(from: number, to: number): boolean {
    if (to < 0 || to >= this.totalCells) return false;
    if (!this.isAdjacent(from, to)) return false;
    if (this.hasWall(from, to)) return false;
    if (this.pathSet().has(to)) return false;
    return true;
  }

  nextCheckpointIndex(): number {
    const ps = this.pathSet();
    for (let i = 0; i < this.checkpoints.length; i++) {
      if (!ps.has(this.checkpoints[i].index)) return i;
    }
    return this.checkpoints.length;
  }

  wouldSkipCheckpoint(cellIndex: number): boolean {
    const nci = this.nextCheckpointIndex();
    if (nci >= this.checkpoints.length) return false;
    if (cellIndex === this.checkpoints[nci].index) return false;
    for (let i = nci; i < this.checkpoints.length; i++) {
      if (cellIndex === this.checkpoints[i].index && i !== nci) return true;
    }
    return false;
  }

  tryMove(cellIndex: number): void {
    if (this.gameWon()) return;
    if (cellIndex < 0 || cellIndex >= this.totalCells) return;
    this.hintMessage.set('');

    const p = this.path();
    const head = p[p.length - 1];

    // Backtrack
    if (p.length >= 2 && cellIndex === p[p.length - 2]) {
      this.undo();
      return;
    }

    if (!this.canMoveTo(head, cellIndex)) return;
    if (this.wouldSkipCheckpoint(cellIndex)) return;

    this.path.update(prev => [...prev, cellIndex]);
    this.checkWin();
  }

  undo(): void {
    if (this.gameWon()) return;
    const p = this.path();
    if (p.length <= 1) return;
    this.path.update(prev => prev.slice(0, -1));
  }

  reset(): void {
    if (this.checkpoints.length === 0) return;
    this.path.set([this.checkpoints[0].index]);
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.clearHintState();
    // Keep timer running without resetting seconds
    this.stopTimer();
    this.timerInterval = setInterval(() => this.timerSeconds.update(v => v + 1), 1000);
  }

  /** Restore a completed game state — shows the winning path with glow */
  restoreCompleted(winningPath: number[]): void {
    this.isRestored.set(true);
    this.path.set(winningPath);
    this.gameWon.set(true);
    this.timerDisabled.set(true);
    this.stopTimer();
  }

  /** Get snapshot of current in-progress state for persistence */
  getProgressSnapshot(): { path: number[]; timerSeconds: number } | null {
    if (this.gameWon() || this.isRestored() || this.timerDisabled()) return null;
    if (this.path().length <= 1) return null; // nothing to save
    return {
      path: [...this.path()],
      timerSeconds: this.timerSeconds(),
    };
  }

  /** Restore a paused in-progress state */
  restorePaused(savedPath: number[], savedTimer: number): void {
    this.path.set(savedPath);
    this.timerSeconds.set(savedTimer);
    this.gameWon.set(false);
    this.timerDisabled.set(false);
    this.isRestored.set(false);
    this.stopTimer(); // stay paused
  }

  private checkWin(): void {
    const p = this.path();

    // All cells must be filled — no empty cells remaining
    if (p.length !== this.totalCells) return;

    // The last cell in the path MUST be the last numbered checkpoint
    const lastCheckpoint = this.checkpoints[this.checkpoints.length - 1];
    if (p[p.length - 1] !== lastCheckpoint.index) return;

    // All checkpoints must have been visited in order along the path
    let cpIdx = 0;
    for (let i = 0; i < p.length; i++) {
      if (cpIdx < this.checkpoints.length && p[i] === this.checkpoints[cpIdx].index) {
        cpIdx++;
      }
    }
    if (cpIdx < this.checkpoints.length) return;

    this.gameWon.set(true);
    this.stopTimer();
  }

  /**
   * Check if the current path matches the solution so far.
   * Returns true if every cell in the path matches the solution path at that position.
   */
  checkCorrect(): boolean {
    const p = this.path();
    for (let i = 0; i < p.length; i++) {
      if (i >= this.solutionPath.length) return false;
      if (p[i] !== this.solutionPath[i]) return false;
    }
    return true;
  }

  /** Pause the timer */
  pauseTimer(): void {
    this.stopTimer();
  }

  /** Resume the timer */
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

  hint(): void {
    if (!this.canHint()) return;
    this.hintCount.update(v => v + 1);

    const p = this.path();
    const head = p[p.length - 1];

    // Find head position in solution path
    const headSolIdx = this.solutionPath.indexOf(head);

    if (headSolIdx === -1 || headSolIdx >= this.solutionPath.length - 1) {
      // Head not on solution path — backtrack one step
      if (p.length > 1) {
        this.path.update(prev => prev.slice(0, -1));
        this.showHintMessage('E kthyem një hap prapa!');
      }
    } else {
      // Check if current path matches solution up to this point
      const nextSolCell = this.solutionPath[headSolIdx + 1];

      if (!this.pathSet().has(nextSolCell) && this.canMoveTo(head, nextSolCell)) {
        // Extend by one correct cell
        this.path.update(prev => [...prev, nextSolCell]);
        this.showHintMessage('E zgjatem rrugën!');
        this.checkWin();
      } else {
        // Next solution cell is blocked or already visited — backtrack
        if (p.length > 1) {
          this.path.update(prev => prev.slice(0, -1));
          this.showHintMessage('E kthyem një hap prapa!');
        }
      }
    }

    // Start 5-second cooldown with countdown
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
    if (this.hintCooldownInterval) {
      clearInterval(this.hintCooldownInterval);
      this.hintCooldownInterval = null;
    }
    if (this.hintMessageTimer) {
      clearTimeout(this.hintMessageTimer);
      this.hintMessageTimer = null;
    }
  }

  destroy(): void {
    this.stopTimer();
    this.clearHintState();
  }
}
