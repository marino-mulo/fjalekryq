import { Component, Input, Output, EventEmitter, OnDestroy, effect, HostListener } from '@angular/core';
import { ZipGameService } from '../zip-game.service';

interface WallLine {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

/** A point along the tube path for gradient coloring */
interface TubePoint {
  cx: number;  // center x of cell
  cy: number;  // center y of cell
  pathIndex: number;
}

@Component({
  selector: 'app-zip-board',
  standalone: true,
  imports: [],
  templateUrl: './zip-board.component.html',
  styleUrl: './zip-board.component.scss'
})
export class ZipBoardComponent implements OnDestroy {
  @Input({ required: true }) game!: ZipGameService;
  @Output() win = new EventEmitter<void>();

  private isDragging = false;
  private winEmitted = false;
  private previousWonState = false;

  readonly borderRadius = 14;
  readonly borderWidth = 2.5;

  /** Tube width as fraction of cell size */
  readonly tubeRatio = 0.62;

  /** Cell size adapts to grid: smaller cells for bigger grids, minimum board width ~420px */
  get cellSize(): number {
    const c = this.game.getCols();
    let base: number;
    if (c >= 9) base = 54;
    else if (c >= 8) base = 60;
    else if (c >= 7) base = 64;
    else base = 70;
    // Ensure board width is at least ~420px
    return Math.max(base, Math.ceil(420 / c));
  }

  /** Tube stroke width in px */
  get tubeWidth(): number {
    return Math.round(this.cellSize * this.tubeRatio);
  }

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

  ngOnDestroy(): void {
    this.isDragging = false;
  }

  get rows() { return this.game.getRows(); }
  get cols() { return this.game.getCols(); }
  get cells(): number[] {
    const total = this.game.getTotalCells();
    return total > 0 ? Array.from({ length: total }, (_, i) => i) : [];
  }

  getRow(i: number) { return Math.floor(i / this.cols); }
  getCol(i: number) { return i % this.cols; }

  // SVG dimensions
  get svgWidth() { return this.cols * this.cellSize; }
  get svgHeight() { return this.rows * this.cellSize; }

  /** Get x position of a cell */
  cellX(i: number): number { return this.getCol(i) * this.cellSize; }
  /** Get y position of a cell */
  cellY(i: number): number { return this.getRow(i) * this.cellSize; }

  /** Check if a cell is the next target checkpoint (for pulsing hint) */
  isNextTarget(i: number): boolean {
    const nci = this.game.nextCheckpointIndex();
    const checkpoints = this.game.getCheckpoints();
    return nci < checkpoints.length && checkpoints[nci].index === i && !this.game.pathSet().has(i);
  }

  // ── Grid Lines (thin internal cell borders) ──

  get horizontalGridLines(): WallLine[] {
    const cs = this.cellSize;
    const lines: WallLine[] = [];
    for (let r = 1; r < this.rows; r++) {
      lines.push({ x1: 0, y1: r * cs, x2: this.cols * cs, y2: r * cs });
    }
    return lines;
  }

  get verticalGridLines(): WallLine[] {
    const cs = this.cellSize;
    const lines: WallLine[] = [];
    for (let c = 1; c < this.cols; c++) {
      lines.push({ x1: c * cs, y1: 0, x2: c * cs, y2: this.rows * cs });
    }
    return lines;
  }

  // ── Wall Lines ──

  get wallLines(): WallLine[] {
    const walls = this.game.getWallPairs();
    const cs = this.cellSize;
    const lines: WallLine[] = [];

    for (const [r1, c1, r2, c2] of walls) {
      if (r2 === r1 + 1 && c2 === c1) {
        lines.push({ x1: c1 * cs, y1: r2 * cs, x2: (c1 + 1) * cs, y2: r2 * cs });
      } else if (c2 === c1 + 1 && r2 === r1) {
        lines.push({ x1: c2 * cs, y1: r1 * cs, x2: c2 * cs, y2: (r1 + 1) * cs });
      }
    }

    return lines;
  }

  // ── Tube Path (stroke-based) ──

  /**
   * Build the SVG polyline `points` string for the tube.
   * Goes through center of each cell in path order.
   */
  get tubePolylinePoints(): string {
    const path = this.game.path();
    if (path.length === 0) return '';
    const cs = this.cellSize;
    const half = cs / 2;
    return path.map(ci => {
      const [r, c] = this.game.rc(ci);
      return `${c * cs + half},${r * cs + half}`;
    }).join(' ');
  }

  /** Does the tube have at least one cell? */
  get hasTube(): boolean {
    return this.game.path().length > 0;
  }

  /**
   * Build gradient stops for the tube.
   * We create an SVG linearGradient along the path direction.
   * For simplicity, we use a horizontal gradient with color stops.
   */
  get tubeGradientStops(): { offset: string; color: string }[] {
    const path = this.game.path();
    if (path.length <= 1) {
      return [
        { offset: '0%', color: 'rgb(168, 85, 247)' },
        { offset: '100%', color: 'rgb(168, 85, 247)' }
      ];
    }

    // Sample a few stops along the path
    const numStops = Math.min(path.length, 8);
    const stops: { offset: string; color: string }[] = [];
    for (let i = 0; i < numStops; i++) {
      const t = i / (numStops - 1);
      const r = Math.round(168 + (124 - 168) * t);
      const g = Math.round(85 + (58 - 85) * t);
      const b = Math.round(247 + (237 - 247) * t);
      stops.push({
        offset: `${Math.round(t * 100)}%`,
        color: `rgb(${r}, ${g}, ${b})`
      });
    }
    return stops;
  }

  /**
   * Calculate gradient direction based on path start → end positions.
   */
  get tubeGradientCoords(): { x1: string; y1: string; x2: string; y2: string } {
    const path = this.game.path();
    if (path.length <= 1) return { x1: '0%', y1: '0%', x2: '100%', y2: '0%' };

    const cs = this.cellSize;
    const half = cs / 2;
    const [sr, sc] = this.game.rc(path[0]);
    const [er, ec] = this.game.rc(path[path.length - 1]);

    const sx = sc * cs + half;
    const sy = sr * cs + half;
    const ex = ec * cs + half;
    const ey = er * cs + half;

    // Use userSpaceOnUse coordinates converted to percentages
    const w = this.svgWidth;
    const h = this.svgHeight;

    return {
      x1: `${(sx / w * 100).toFixed(1)}%`,
      y1: `${(sy / h * 100).toFixed(1)}%`,
      x2: `${(ex / w * 100).toFixed(1)}%`,
      y2: `${(ey / h * 100).toFixed(1)}%`
    };
  }

  /**
   * Generate individual tube segment lines for per-segment coloring.
   * Each segment is a line from one cell center to the next.
   */
  get tubeSegmentLines(): { x1: number; y1: number; x2: number; y2: number; color: string; index: number }[] {
    const path = this.game.path();
    if (path.length < 2) return [];

    const cs = this.cellSize;
    const half = cs / 2;
    const segments: { x1: number; y1: number; x2: number; y2: number; color: string; index: number }[] = [];

    for (let i = 0; i < path.length - 1; i++) {
      const [r1, c1] = this.game.rc(path[i]);
      const [r2, c2] = this.game.rc(path[i + 1]);
      const t = path.length <= 2 ? 0 : i / (path.length - 2);
      const rr = Math.round(168 + (124 - 168) * t);
      const g = Math.round(85 + (58 - 85) * t);
      const b = Math.round(247 + (237 - 247) * t);

      segments.push({
        x1: c1 * cs + half,
        y1: r1 * cs + half,
        x2: c2 * cs + half,
        y2: r2 * cs + half,
        color: `rgb(${rr}, ${g}, ${b})`,
        index: i
      });
    }

    return segments;
  }

  /**
   * Head circle position (last cell in path)
   */
  get headPosition(): { cx: number; cy: number } | null {
    const path = this.game.path();
    if (path.length === 0) return null;
    const cs = this.cellSize;
    const half = cs / 2;
    const last = path[path.length - 1];
    const [r, c] = this.game.rc(last);
    return { cx: c * cs + half, cy: r * cs + half };
  }

  /**
   * Start circle position (first cell in path)
   */
  get startPosition(): { cx: number; cy: number } | null {
    const path = this.game.path();
    if (path.length === 0) return null;
    const cs = this.cellSize;
    const half = cs / 2;
    const first = path[0];
    const [r, c] = this.game.rc(first);
    return { cx: c * cs + half, cy: r * cs + half };
  }

  // ── Checkpoint Overlays ──

  get checkpointRadius(): number {
    return Math.round(this.cellSize * 0.24);
  }

  get checkpointOverlays(): { x: number; y: number; value: number; onPath: boolean }[] {
    const checkpoints = this.game.getCheckpoints();
    const pathSet = this.game.pathSet();
    const cs = this.cellSize;
    const overlays: { x: number; y: number; value: number; onPath: boolean }[] = [];

    for (const cp of checkpoints) {
      const [r, c] = this.game.rc(cp.index);
      overlays.push({
        x: c * cs + cs / 2,
        y: r * cs + cs / 2,
        value: cp.value,
        onPath: pathSet.has(cp.index)
      });
    }

    return overlays;
  }

  // ── Input Handling ──

  onMouseDown(e: MouseEvent, i: number) {
    if (this.game.gameWon()) return;
    e.preventDefault();
    this.isDragging = true;
    this.game.tryMove(i);
  }

  onMouseEnter(i: number) {
    if (!this.isDragging || this.game.gameWon()) return;
    this.game.tryMove(i);
  }

  @HostListener('document:mouseup')
  onMouseUp() { this.isDragging = false; }

  onTouchStart(e: TouchEvent, i: number) {
    if (this.game.gameWon()) return;
    e.preventDefault();
    this.isDragging = true;
    this.game.tryMove(i);
  }

  onTouchMove(e: TouchEvent) {
    if (!this.isDragging || this.game.gameWon()) return;
    e.preventDefault();
    const touch = e.touches[0];
    const el = document.elementFromPoint(touch.clientX, touch.clientY);
    if (el && el.hasAttribute('data-index')) {
      this.game.tryMove(Number(el.getAttribute('data-index')));
    }
  }

  @HostListener('document:keydown', ['$event'])
  onKeyDown(e: KeyboardEvent) {
    if (this.game.gameWon()) return;
    const head = this.game.currentHead();
    if (head === -1) return;
    const [r, c] = this.game.rc(head);
    let target = -1;
    if (e.key === 'ArrowUp' && r > 0) target = this.game.idx(r - 1, c);
    else if (e.key === 'ArrowDown' && r < this.rows - 1) target = this.game.idx(r + 1, c);
    else if (e.key === 'ArrowLeft' && c > 0) target = this.game.idx(r, c - 1);
    else if (e.key === 'ArrowRight' && c < this.cols - 1) target = this.game.idx(r, c + 1);
    else if (e.key === 'z' && (e.ctrlKey || e.metaKey)) { this.game.undo(); return; }
    else return;
    e.preventDefault();
    this.game.tryMove(target);
  }
}
