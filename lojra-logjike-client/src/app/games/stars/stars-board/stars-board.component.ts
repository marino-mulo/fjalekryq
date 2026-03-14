import { Component, Input, Output, EventEmitter, effect, ElementRef, ViewChild } from '@angular/core';
import { StarsGameService, EMPTY, STAR, MARK_X, AUTO_X } from '../stars-game.service';

interface ZoneBorder {
  x1: number; y1: number; x2: number; y2: number;
}

@Component({
  selector: 'app-stars-board',
  standalone: true,
  imports: [],
  templateUrl: './stars-board.component.html',
  styleUrl: './stars-board.component.scss'
})
export class StarsBoardComponent {
  @Input({ required: true }) game!: StarsGameService;
  @Output() win = new EventEmitter<void>();

  private previousWonState = false;
  private winEmitted = false;

  // Warm pastel zone colors (amber/yellow palette + variety)
  readonly zoneColors = [
    '#FFE4B3', '#FFD6CC', '#FFFAB3', '#D4F4B3', '#B3F4E6',
    '#B3D4FF', '#C8B3FF', '#FFB3E6', '#FFB3B3', '#B3FFD6', '#F4FFB3', '#E6D4FF'
  ];

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

  get cellSize(): number {
    const s = this.size;
    let base: number;
    if (s >= 12) base = 40;
    else if (s >= 11) base = 44;
    else if (s >= 10) base = 48;
    else if (s >= 9) base = 52;
    else if (s >= 8) base = 56;
    else base = 64;
    // Ensure board width is at least ~420px
    return Math.max(base, Math.ceil(420 / s));
  }

  get svgWidth(): number { return this.size * this.cellSize; }
  get svgHeight(): number { return this.size * this.cellSize; }

  cellRow(i: number): number { return Math.floor(i / this.size); }
  cellCol(i: number): number { return i % this.size; }
  cellX(i: number): number { return this.cellCol(i) * this.cellSize; }
  cellY(i: number): number { return this.cellRow(i) * this.cellSize; }

  zoneColor(_i: number): string {
    return '#ffffff';
  }

  isStar(i: number): boolean {
    return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === STAR;
  }

  isMarkX(i: number): boolean {
    const val = this.game.board()[this.cellRow(i)]?.[this.cellCol(i)];
    return val === MARK_X || val === AUTO_X;
  }

  onCellClick(i: number): void {
    if (this.didDrag) { this.didDrag = false; return; }
    this.game.toggleCell(this.cellRow(i), this.cellCol(i));
  }

  get zoneBorders(): ZoneBorder[] {
    const borders: ZoneBorder[] = [];
    const n = this.size, cs = this.cellSize;
    const zones = this.game.getZones();
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (c < n - 1 && zones[r][c] !== zones[r][c + 1])
          borders.push({ x1: (c + 1) * cs, y1: r * cs, x2: (c + 1) * cs, y2: (r + 1) * cs });
        if (r < n - 1 && zones[r][c] !== zones[r + 1][c])
          borders.push({ x1: c * cs, y1: (r + 1) * cs, x2: (c + 1) * cs, y2: (r + 1) * cs });
      }
    }
    return borders;
  }

  get horizontalGridLines(): { y: number }[] {
    const lines = [];
    for (let r = 1; r < this.size; r++) lines.push({ y: r * this.cellSize });
    return lines;
  }

  get verticalGridLines(): { x: number }[] {
    const lines = [];
    for (let c = 1; c < this.size; c++) lines.push({ x: c * this.cellSize });
    return lines;
  }

  get starSize(): number { return this.cellSize * 0.42; }
  starX(i: number): number { return this.cellX(i) + this.cellSize / 2; }
  starY(i: number): number { return this.cellY(i) + this.cellSize / 2; }

  /** Staggered delay for each star's win dance animation */
  starWinDelay(i: number): number {
    const starCells = this.cells.filter(c => this.isStar(c));
    const idx = starCells.indexOf(i);
    return idx >= 0 ? idx * 120 : 0;
  }

  get xSize(): number { return this.cellSize * 0.32; }

  // ── Drag state ──
  private dragging = false;
  private dragVisited = new Set<number>();
  private didDrag = false;

  @ViewChild('boardSvg', { static: false }) boardSvgRef!: ElementRef<SVGSVGElement>;

  onDragStart(i: number, event: MouseEvent): void {
    if (this.game.gameWon()) return;
    const val = this.game.board()[this.cellRow(i)]?.[this.cellCol(i)];
    if (val === STAR || val === MARK_X) return;
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
    const val = this.game.board()[this.cellRow(i)]?.[this.cellCol(i)];
    if (val === STAR || val === MARK_X) return;
    event.preventDefault();
    this.dragging = true;
    this.dragVisited.clear();
    this.placeXIfEmpty(i);
  }

  onTouchMove(event: TouchEvent): void {
    if (!this.dragging) return;
    event.preventDefault();
    const i = this.getCellFromTouch(event);
    if (i !== -1) this.placeXIfEmpty(i);
  }

  private placeXIfEmpty(i: number): void {
    if (this.dragVisited.has(i)) return;
    this.dragVisited.add(i);
    const r = this.cellRow(i), c = this.cellCol(i);
    const val = this.game.board()[r]?.[c];
    if (val !== EMPTY && val !== AUTO_X) return;

    // Save undo snapshot for each cell placement
    (this.game as any).history.push(this.game.board().map((row: number[]) => [...row]));
    (this.game as any).historyLength.set((this.game as any).history.length);

    const b = this.game.board().map((row: number[]) => [...row]);
    b[r][c] = MARK_X;
    this.game.board.set(b);
    this.didDrag = true;
  }

  private getCellFromTouch(event: TouchEvent): number {
    const touch = event.touches[0];
    if (!touch) return -1;
    const svg = (event.currentTarget as SVGSVGElement);
    const rect = svg.getBoundingClientRect();
    const col = Math.floor((touch.clientX - rect.left) / this.cellSize);
    const row = Math.floor((touch.clientY - rect.top) / this.cellSize);
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return -1;
    return row * this.size + col;
  }

  isHintCell(i: number): boolean {
    const cells = this.game.hintCells();
    if (cells.length === 0) return false;
    return cells.some(cell => cell.row === this.cellRow(i) && cell.col === this.cellCol(i));
  }

  isConflict(i: number): boolean {
    const cells = this.game.conflictCells();
    if (cells.length === 0) return false;
    return cells.some(cell => cell.row === this.cellRow(i) && cell.col === this.cellCol(i));
  }

  get hasConflicts(): boolean { return this.game.conflictCells().length > 0; }
}
