import { Component, Input, Output, EventEmitter, effect } from '@angular/core';
import { SnakeGameService, EMPTY, SNAKE, MARK_X } from '../snake-game.service';

@Component({
  selector: 'app-snake-board',
  standalone: true,
  imports: [],
  templateUrl: './snake-board.component.html',
  styleUrl: './snake-board.component.scss'
})
export class SnakeBoardComponent {
  @Input({ required: true }) game!: SnakeGameService;
  @Output() win = new EventEmitter<void>();

  private previousWonState = false;
  private winEmitted = false;

  constructor() {
    effect(() => {
      const won = this.game.gameWon();
      const restored = this.game.isRestored();
      if (won && !this.previousWonState && !this.winEmitted && !restored) {
        this.winEmitted = true;
        setTimeout(() => this.win.emit(), 800);
      } else if (!won) {
        this.winEmitted = false;
      }
      this.previousWonState = won;
    });
  }

  get size(): number { return this.game.getSize(); }
  get cells(): number[] { return Array.from({ length: this.size * this.size }, (_, i) => i); }
  get rowIndices(): number[] { return Array.from({ length: this.size }, (_, i) => i); }
  get colIndices(): number[] { return Array.from({ length: this.size }, (_, i) => i); }

  get cellSize(): number {
    const s = this.size;
    let base: number;
    if (s >= 8) base = 64;
    else if (s >= 7) base = 70;
    else if (s >= 6) base = 76;
    else base = 84;
    // Ensure board width is at least ~420px
    return Math.max(base, Math.ceil(420 / s));
  }

  get clueSize(): number { return 28; }
  private get margin(): number { return 4; }

  // Board SVG offset (leave room for clue labels)
  get boardOffsetX(): number { return this.clueSize; }
  get boardOffsetY(): number { return this.clueSize; }

  get svgWidth(): number { return this.size * this.cellSize + this.clueSize + this.margin; }
  get svgHeight(): number { return this.size * this.cellSize + this.clueSize + this.margin; }

  // Board inner dims
  get boardW(): number { return this.size * this.cellSize; }
  get boardH(): number { return this.size * this.cellSize; }

  // Snake body visual sizing:
  // snakeCircleR — radius of each body circle (≈38% of cell)
  // snakeBodyWidth — connector stroke-width = circle diameter, so round-cap connectors
  //   blend seamlessly into circles, creating a continuous snake-tube look
  get snakeCircleR(): number { return this.cellSize * 0.38; }
  get snakeBodyWidth(): number { return this.snakeCircleR * 2; }
  /** Tail teardrop radius — same as body radius to blend seamlessly with connector */
  get tailR(): number { return this.snakeBodyWidth / 2; }

  cellRow(i: number): number { return Math.floor(i / this.size); }
  cellCol(i: number): number { return i % this.size; }

  // Cell coords within the board group
  cellX(i: number): number { return this.cellCol(i) * this.cellSize; }
  cellY(i: number): number { return this.cellRow(i) * this.cellSize; }

  isSnake(i: number): boolean { return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === SNAKE; }
  isMarkX(i: number): boolean { return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === MARK_X; }

  isHead(i: number): boolean {
    return this.cellRow(i) === this.game.getHeadRow() && this.cellCol(i) === this.game.getHeadCol();
  }

  isTail(i: number): boolean {
    return this.cellRow(i) === this.game.getTailRow() && this.cellCol(i) === this.game.getTailCol();
  }

  /**
   * Returns the rotation angle (degrees) for the tail teardrop.
   * The shape is drawn pointing RIGHT (0°). We rotate so it points
   * AWAY from the body neighbor.
   * dir → body neighbor direction → tail tip opposite → rotation
   *   body above  → tail tip points DOWN  → 90°
   *   body below  → tail tip points UP    → 270°
   *   body left   → tail tip points RIGHT → 0°
   *   body right  → tail tip points LEFT  → 180°
   */
  get tailRotation(): number {
    const b = this.game.board();
    const tr = this.game.getTailRow();
    const tc = this.game.getTailCol();
    // [dr, dc] → rotation so teardrop points AWAY from that neighbor
    const dirs: [number, number, number][] = [[-1, 0, 90], [1, 0, 270], [0, -1, 0], [0, 1, 180]];
    for (const [dr, dc, angle] of dirs) {
      const nr = tr + dr, nc = tc + dc;
      if (nr >= 0 && nr < this.size && nc >= 0 && nc < this.size && b[nr]?.[nc] === SNAKE) {
        return angle;
      }
    }
    return 0;
  }

  /**
   * Returns the rotation angle (degrees) for the head.
   * Eyes are drawn at top-left / top-right (facing UP = 0°).
   * We rotate so eyes face AWAY from the body neighbor.
   *   body above  → face DOWN  → 180°
   *   body below  → face UP    → 0°
   *   body left   → face RIGHT → 90°
   *   body right  → face LEFT  → 270°
   */
  get headRotation(): number {
    const b = this.game.board();
    const hr = this.game.getHeadRow();
    const hc = this.game.getHeadCol();
    const dirs: [number, number, number][] = [[-1, 0, 180], [1, 0, 0], [0, -1, 90], [0, 1, 270]];
    for (const [dr, dc, angle] of dirs) {
      const nr = hr + dr, nc = hc + dc;
      if (nr >= 0 && nr < this.size && nc >= 0 && nc < this.size && b[nr]?.[nc] === SNAKE) {
        return angle;
      }
    }
    return 0;
  }

  isGiven(i: number): boolean {
    return this.game.isGiven(this.cellRow(i), this.cellCol(i));
  }

  onCellClick(i: number): void {
    if (this.didDrag) { this.didDrag = false; return; }
    this.game.toggleCell(this.cellRow(i), this.cellCol(i));
  }

  isHintCell(i: number): boolean {
    const cells = this.game.hintCells();
    if (cells.length === 0) return false;
    return cells.some(c => c.row === this.cellRow(i) && c.col === this.cellCol(i));
  }

  isConflict(i: number): boolean {
    const cells = this.game.conflictCells();
    if (cells.length === 0) return false;
    return cells.some(c => c.row === this.cellRow(i) && c.col === this.cellCol(i));
  }

  get xSize(): number { return this.cellSize * 0.14; }

  rowClueX(col: number): number { return this.boardOffsetX + col * this.cellSize + this.cellSize / 2; }
  colClueY(row: number): number { return this.boardOffsetY + row * this.cellSize + this.cellSize / 2; }

  rowClueHighlight(row: number): boolean {
    const b = this.game.board();
    const count = b[row]?.filter(c => c === SNAKE).length ?? 0;
    return count === this.game.getRowClues()[row];
  }

  colClueHighlight(col: number): boolean {
    const b = this.game.board();
    let count = 0;
    for (let r = 0; r < this.size; r++) if (b[r]?.[col] === SNAKE) count++;
    return count === this.game.getColClues()[col];
  }

  // ── Drag state ──
  private dragging = false;
  private dragVisited = new Set<number>();
  private didDrag = false;
  private touchStartCell = -1;

  onDragStart(i: number, event: MouseEvent): void {
    if (this.game.gameWon()) return;
    const r = this.cellRow(i), c = this.cellCol(i);
    if ((r === this.game.getHeadRow() && c === this.game.getHeadCol()) ||
        (r === this.game.getTailRow() && c === this.game.getTailCol()) ||
        this.game.isGiven(r, c)) return;
    const val = this.game.board()[r]?.[c];
    if (val === SNAKE || val === MARK_X) return;
    event.preventDefault();
    this.dragging = true;
    this.dragVisited.clear();
    this.placeXIfEmpty(i);
  }

  onDragOver(i: number): void {
    if (!this.dragging) return;
    this.placeXIfEmpty(i);
  }

  onDragEnd(): void {
    this.dragging = false;
    this.dragVisited.clear();
  }

  onTouchStart(event: TouchEvent): void {
    if (this.game.gameWon()) return;
    const i = this.getCellFromTouch(event);
    if (i === -1) return;
    event.preventDefault();
    this.touchStartCell = i;
    this.dragging = false;
    this.dragVisited.clear();
  }

  onTouchMove(event: TouchEvent): void {
    event.preventDefault();
    const i = this.getCellFromTouch(event);
    if (i === -1) return;
    if (!this.dragging && i !== this.touchStartCell) {
      this.dragging = true;
      this.placeXIfEmpty(this.touchStartCell);
    }
    if (this.dragging) this.placeXIfEmpty(i);
  }

  onTouchEnd(): void {
    if (!this.dragging && this.touchStartCell !== -1) {
      this.game.toggleCell(this.cellRow(this.touchStartCell), this.cellCol(this.touchStartCell));
    }
    this.dragging = false;
    this.dragVisited.clear();
    this.touchStartCell = -1;
  }

  // Drag paints X marks (not snake) — lets user quickly mark cells to exclude
  private placeXIfEmpty(i: number): void {
    if (this.dragVisited.has(i)) return;
    this.dragVisited.add(i);
    const r = this.cellRow(i), c = this.cellCol(i);
    const val = this.game.board()[r]?.[c];
    if (val !== EMPTY) return; // only paint empty cells

    // Save undo snapshot for each cell placement
    (this.game as any).history.push(this.game.board().map((row: number[]) => [...row]));
    (this.game as any).historyLength.set((this.game as any).history.length);
    const b = this.game.board().map((row: number[]) => [...row]);
    b[r][c] = MARK_X;
    this.game.board.set(b);
    this.game.updateConflicts();
    this.didDrag = true;
  }

  private getCellFromTouch(event: TouchEvent): number {
    const touch = event.touches[0];
    if (!touch) return -1;
    const svg = event.currentTarget as SVGSVGElement;
    const rect = svg.getBoundingClientRect();
    const scaleX = this.svgWidth / rect.width;
    const scaleY = this.svgHeight / rect.height;
    const x = (touch.clientX - rect.left) * scaleX - this.boardOffsetX;
    const y = (touch.clientY - rect.top) * scaleY - this.boardOffsetY;
    const col = Math.floor(x / this.cellSize);
    const row = Math.floor(y / this.cellSize);
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return -1;
    return row * this.size + col;
  }

  /** True if a snake cell has no adjacent snake neighbors — rendered as a dot cap */
  isIsolated(i: number): boolean {
    const b = this.game.board();
    const r = this.cellRow(i), c = this.cellCol(i);
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (const [dr, dc] of dirs) {
      const nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < this.size && nc >= 0 && nc < this.size && b[nr][nc] === SNAKE) return false;
    }
    return true;
  }

  /**
   * Walk from a given start cell through connected SNAKE cells (single path, no branching).
   * Returns ordered array of cell indices.
   */
  private walkSnakePath(startRow: number, startCol: number): number[] {
    const b = this.game.board();
    const n = this.size;
    if (b[startRow]?.[startCol] !== SNAKE) return [];
    const path: number[] = [];
    let prevIdx = -1;
    let curIdx = startRow * n + startCol;
    while (true) {
      path.push(curIdx);
      const r = Math.floor(curIdx / n), c = curIdx % n;
      let nextIdx = -1;
      for (const [dr, dc] of [[-1,0],[1,0],[0,-1],[0,1]] as [number,number][]) {
        const nr = r + dr, nc = c + dc;
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
        const ni = nr * n + nc;
        if (ni === prevIdx || b[nr][nc] !== SNAKE) continue;
        nextIdx = ni; break;
      }
      if (nextIdx === -1) break;
      prevIdx = curIdx;
      curIdx = nextIdx;
    }
    return path;
  }

  /**
   * Walk from head → tail through connected SNAKE cells.
   * Returns ordered array of cell indices. If disconnected, returns
   * only the component reachable from the head.
   */
  get snakePath(): number[] {
    return this.walkSnakePath(this.game.getHeadRow(), this.game.getHeadCol());
  }

  /**
   * Cell-index → position 0..1 along the snake path (head=0, tail=1).
   *
   * Strategy:
   * 1. Walk from head → collect cells with t = i / (total-1)
   * 2. Walk from tail → collect cells with t = 1 - i / (total-1)
   * 3. Merge: head-walk wins for cells reachable from head;
   *    tail-walk fills in cells only reachable from the tail end.
   *    This ensures tail-adjacent disconnected clusters get near-red values.
   */
  private get pathIndexMap(): Map<number, number> {
    const map = new Map<number, number>();

    // Walk from head
    const headPath = this.walkSnakePath(this.game.getHeadRow(), this.game.getHeadCol());
    const headTotal = headPath.length;
    for (let i = 0; i < headTotal; i++) {
      map.set(headPath[i], headTotal <= 1 ? 0 : i / (headTotal - 1));
    }

    // Walk from tail — only add cells NOT already mapped by head walk
    const tailPath = this.walkSnakePath(this.game.getTailRow(), this.game.getTailCol());
    const tailTotal = tailPath.length;
    for (let i = 0; i < tailTotal; i++) {
      const cellIdx = tailPath[i];
      if (!map.has(cellIdx)) {
        // t from tail perspective: i=0 is the tail (t=1), increases toward the other end
        map.set(cellIdx, tailTotal <= 1 ? 1 : 1 - i / (tailTotal - 1));
      }
    }

    return map;
  }

  /** Interpolate green→red. t=0 → head green (#10b981), t=1 → tail red (#ef4444) */
  lerpColor(t: number): string {
    const r = Math.round(16  + (239 - 16)  * t);
    const g = Math.round(185 + (68  - 185) * t);
    const b = Math.round(129 + (68  - 129) * t);
    return `rgb(${r},${g},${b})`;
  }

  /**
   * Returns ALL adjacent-snake-cell pairs as renderable segments.
   * Segments on the connected path get interpolated green→red colors.
   * Segments NOT on the path (disconnected clusters) get solid teal.
   */
  get snakeSegments(): {
    x1: number; y1: number; x2: number; y2: number;
    gradId: string; c1: string; c2: string; pathPos: number;
  }[] {
    const b = this.game.board();
    const n = this.size;
    const pathMap = this.pathIndexMap;
    const TEAL = '#14B8A6';
    const result: {
      x1: number; y1: number; x2: number; y2: number;
      gradId: string; c1: string; c2: string; pathPos: number;
    }[] = [];
    let segIdx = 0;

    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (b[r][c] !== SNAKE) continue;
        // Only emit rightward and downward segments to avoid duplicates
        for (const [dr, dc] of [[0,1],[1,0]] as [number,number][]) {
          const nr = r + dr, nc = c + dc;
          if (nr >= n || nc >= n) continue;
          if (b[nr][nc] !== SNAKE) continue;
          const i1 = r * n + c, i2 = nr * n + nc;
          const t1 = pathMap.get(i1);
          const t2 = pathMap.get(i2);
          const col1 = t1 !== undefined ? this.lerpColor(t1) : TEAL;
          const col2 = t2 !== undefined ? this.lerpColor(t2) : TEAL;
          result.push({
            x1: c * this.cellSize + this.cellSize / 2,
            y1: r * this.cellSize + this.cellSize / 2,
            x2: nc * this.cellSize + this.cellSize / 2,
            y2: nr * this.cellSize + this.cellSize / 2,
            gradId: `sg-${segIdx++}`,
            c1: col1, c2: col2,
            pathPos: t1 ?? 0,
          });
        }
      }
    }
    return result;
  }

  /** Color of a single isolated snake cell (no neighbors) — teal if off-path, interpolated if on path */
  isolatedColor(i: number): string {
    const t = this.pathIndexMap.get(i);
    return t !== undefined ? this.lerpColor(t) : '#14B8A6';
  }

  /** Size of the head SVG icon (slightly larger than body width for visual presence) */
  get headIconSize(): number { return this.snakeBodyWidth * 1.35; }
  /** Size of the tail SVG icon */
  get tailIconSize(): number { return this.snakeBodyWidth * 1.35; }
  /** Head color (always green end) */
  get headColor(): string { return this.lerpColor(0); }
  /** Tail color (always red end) */
  get tailColor(): string { return this.lerpColor(1); }

  /** Path position (0..1) for an isolated dot cell */
  isolatedPathPos(i: number): number {
    return this.pathIndexMap.get(i) ?? 0;
  }

  /** Win animation delay based on path position 0..1 → 0..700ms */
  winAnimDelay(pathPos: number): number {
    return Math.round(pathPos * 700);
  }
}
