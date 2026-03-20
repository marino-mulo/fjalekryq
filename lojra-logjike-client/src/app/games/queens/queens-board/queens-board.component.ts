import { Component, Input, Output, EventEmitter, effect, ElementRef, ViewChild } from '@angular/core';
import { QueensGameService, EMPTY, QUEEN, MARK_X, AUTO_X } from '../queens-game.service';

interface ZoneBorder {
  x1: number; y1: number; x2: number; y2: number;
}

@Component({
  selector: 'app-queens-board',
  standalone: true,
  imports: [],
  templateUrl: './queens-board.component.html',
  styleUrl: './queens-board.component.scss'
})
export class QueensBoardComponent {
  @Input({ required: true }) game!: QueensGameService;
  @Output() win = new EventEmitter<void>();

  private previousWonState = false;
  private winEmitted = false;

  // Zone pastel colors
  readonly zoneColors = [
    '#FFB3B3', '#FFDAB3', '#FFF1B3', '#B3FFB3', '#B3FFE0',
    '#B3E0FF', '#B3B3FF', '#DAB3FF', '#FFB3E6', '#FFD6CC', '#C2F0C2'
  ];

  // Hide animation tracking
  hidingQueens: { key: number; x: number; y: number }[] = [];
  private hidingCounter = 0;

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
    if (s >= 11) base = 44;
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

  zoneColor(i: number): string {
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    const zone = this.game.getZones()[r]?.[c] ?? 0;
    return this.zoneColors[zone % this.zoneColors.length];
  }

  isQueen(i: number): boolean {
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    return this.game.board()[r]?.[c] === QUEEN;
  }

  isMarkX(i: number): boolean {
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    const val = this.game.board()[r]?.[c];
    return val === MARK_X || val === AUTO_X;
  }

  onCellClick(i: number): void {
    // Skip click if a drag just placed X marks (drag fires mousedown+mouseup+click)
    if (this.didDrag) {
      this.didDrag = false;
      return;
    }
    if (this.isQueen(i)) this.addHidingQueen(i);
    this.game.toggleCell(this.cellRow(i), this.cellCol(i));
  }

  private addHidingQueen(i: number): void {
    const entry = {
      key: this.hidingCounter++,
      x: this.queenX(i),
      y: this.queenY(i)
    };
    this.hidingQueens.push(entry);
    setTimeout(() => {
      this.hidingQueens = this.hidingQueens.filter(h => h.key !== entry.key);
    }, 300);
  }

  // Zone borders: thick lines between cells of different zones
  get zoneBorders(): ZoneBorder[] {
    const borders: ZoneBorder[] = [];
    const n = this.size;
    const cs = this.cellSize;
    const zones = this.game.getZones();

    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        // Right neighbor
        if (c < n - 1 && zones[r][c] !== zones[r][c + 1]) {
          borders.push({
            x1: (c + 1) * cs, y1: r * cs,
            x2: (c + 1) * cs, y2: (r + 1) * cs
          });
        }
        // Bottom neighbor
        if (r < n - 1 && zones[r][c] !== zones[r + 1][c]) {
          borders.push({
            x1: c * cs, y1: (r + 1) * cs,
            x2: (c + 1) * cs, y2: (r + 1) * cs
          });
        }
      }
    }
    return borders;
  }

  // Thin grid lines
  get horizontalGridLines(): { y: number }[] {
    const lines = [];
    for (let r = 1; r < this.size; r++) {
      lines.push({ y: r * this.cellSize });
    }
    return lines;
  }

  get verticalGridLines(): { x: number }[] {
    const lines = [];
    for (let c = 1; c < this.size; c++) {
      lines.push({ x: c * this.cellSize });
    }
    return lines;
  }

  // Queen crown SVG dimensions relative to cell
  get queenSize(): number { return this.cellSize * 0.45; }
  queenX(i: number): number { return this.cellX(i) + this.cellSize / 2; }
  queenY(i: number): number { return this.cellY(i) + this.cellSize / 2; }

  /** Staggered delay for each queen's win dance animation */
  queenWinDelay(i: number): number {
    const queenCells = this.cells.filter(c => this.isQueen(c));
    const idx = queenCells.indexOf(i);
    return idx >= 0 ? idx * 120 : 0;
  }

  // X mark size
  get xSize(): number { return this.cellSize * 0.36; }

  // ── Drag-to-place-X state ──
  private dragging = false;
  private dragVisited = new Set<number>();
  private didDrag = false;  // true if drag actually placed any X
  private touchStartCell = -1; // cell where touch began (for tap detection)

  @ViewChild('boardSvg', { static: false }) boardSvgRef!: ElementRef<SVGSVGElement>;

  onDragStart(i: number, event: MouseEvent): void {
    if (this.game.gameWon()) return;
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    const val = this.game.board()[r]?.[c];
    // Only start drag if cell is empty or auto-x (not queen, not manual-x)
    if (val === QUEEN || val === MARK_X) return;

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
    // didDrag stays true until the click event fires (or is cleared next click)
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
    // Start drag only when finger moves to a different cell
    if (!this.dragging && i !== this.touchStartCell) {
      this.dragging = true;
      this.placeXIfEmpty(this.touchStartCell);
    }
    if (this.dragging) this.placeXIfEmpty(i);
  }

  onTouchEnd(): void {
    if (!this.dragging && this.touchStartCell !== -1) {
      // It was a tap, not a drag — use normal toggle cycle
      if (this.isQueen(this.touchStartCell)) this.addHidingQueen(this.touchStartCell);
      this.game.toggleCell(this.cellRow(this.touchStartCell), this.cellCol(this.touchStartCell));
    }
    this.dragging = false;
    this.dragVisited.clear();
    this.touchStartCell = -1;
  }

  private placeXIfEmpty(i: number): void {
    if (this.dragVisited.has(i)) return;
    this.dragVisited.add(i);

    const r = this.cellRow(i);
    const c = this.cellCol(i);
    const val = this.game.board()[r]?.[c];
    if (val !== EMPTY && val !== AUTO_X) return;

    // Save undo snapshot for each cell placement
    (this.game as any).history.push(this.game.board().map((row: number[]) => [...row]));
    (this.game as any).historyLength.set((this.game as any).history.length);

    // Place MARK_X directly on the board
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
    const scaleX = this.svgWidth / rect.width;
    const scaleY = this.svgHeight / rect.height;
    const x = (touch.clientX - rect.left) * scaleX;
    const y = (touch.clientY - rect.top) * scaleY;
    const col = Math.floor(x / this.cellSize);
    const row = Math.floor(y / this.cellSize);
    if (row < 0 || row >= this.size || col < 0 || col >= this.size) return -1;
    return row * this.size + col;
  }

  // Hint cell highlight
  isHintCell(i: number): boolean {
    const cells = this.game.hintCells();
    if (cells.length === 0) return false;
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    return cells.some(cell => cell.row === r && cell.col === c);
  }

  // Conflict detection
  isConflict(i: number): boolean {
    const cells = this.game.conflictCells();
    if (cells.length === 0) return false;
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    return cells.some(cell => cell.row === r && cell.col === c);
  }

  get hasConflicts(): boolean {
    return this.game.conflictCells().length > 0;
  }
}
