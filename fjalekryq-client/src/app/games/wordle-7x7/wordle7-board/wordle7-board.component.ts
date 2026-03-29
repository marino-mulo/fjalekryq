import { Component, Input, Output, EventEmitter, effect, signal } from '@angular/core';
import { Wordle7GameService, CellColor } from '../wordle7-game.service';

// Cell size lookup to keep total board around ~388px wide
const CELL_SIZE_MAP: Record<number, number> = { 7: 68, 8: 60, 9: 52, 10: 46, 11: 40, 12: 37, 13: 34 };
const FONT_SIZE_MAP: Record<number, number> = { 7: 28, 8: 25, 9: 22, 10: 19, 11: 17, 12: 15, 13: 14 };

@Component({
  selector: 'app-wordle7-board',
  standalone: true,
  imports: [],
  templateUrl: './wordle7-board.component.html',
  styleUrl: './wordle7-board.component.scss'
})
export class Wordle7BoardComponent {
  @Input({ required: true }) game!: Wordle7GameService;
  @Output() win = new EventEmitter<void>();

  private winEmitted = false;
  private previousWonState = false;

  readonly flyingCells = signal<Array<{ row: number; col: number; fromDx: number; fromDy: number }>>([]);
  private flyTimer: ReturnType<typeof setTimeout> | null = null;

  readonly gap = 3;
  readonly borderWidth = 2.5;
  readonly outerRadius = 14;

  constructor() {
    effect(() => {
      const won = this.game.gameWon();
      if (won && !this.previousWonState && !this.winEmitted) {
        this.winEmitted = true;
        setTimeout(() => this.win.emit(), 600);
      } else if (!won) {
        this.winEmitted = false;
      }
      this.previousWonState = won;
    });

    effect(() => {
      const swaps = this.game.lastSwap();
      if (!swaps || swaps.length === 0) return;
      if (this.flyTimer) clearTimeout(this.flyTimer);
      this.flyingCells.set(swaps.map(s => ({
        row: s.row,
        col: s.col,
        fromDx: this.cellX(s.fromCol) - this.cellX(s.col),
        fromDy: this.cellY(s.fromRow) - this.cellY(s.row),
      })));
      this.flyTimer = setTimeout(() => {
        this.flyingCells.set([]);
        this.flyTimer = null;
      }, 700);
    }, { allowSignalWrites: true });
  }

  get gridSize(): number {
    return this.game.getGridSize();
  }

  get cellSize(): number {
    return CELL_SIZE_MAP[this.gridSize] ?? 52;
  }

  get fontSize(): number {
    return FONT_SIZE_MAP[this.gridSize] ?? 22;
  }

  get borderRadius(): number {
    return this.cellSize >= 45 ? 10 : 8;
  }

  get svgWidth(): number {
    return this.gridSize * this.cellSize + (this.gridSize + 1) * this.gap;
  }

  get svgHeight(): number {
    return this.svgWidth;
  }

  get cells(): { row: number; col: number }[] {
    const cells: { row: number; col: number }[] = [];
    const size = this.gridSize;
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        cells.push({ row: r, col: c });
      }
    }
    return cells;
  }

  cellX(col: number): number {
    return this.gap + col * (this.cellSize + this.gap);
  }

  cellY(row: number): number {
    return this.gap + row * (this.cellSize + this.gap);
  }

  getLetter(row: number, col: number): string {
    const g = this.game.grid();
    if (g.length === 0) return '';
    return g[row][col];
  }

  isBlocked(row: number, col: number): boolean {
    return this.getLetter(row, col) === 'X';
  }

  isSelected(row: number, col: number): boolean {
    const sel = this.game.selectedCell();
    return sel !== null && sel.row === row && sel.col === col;
  }

  /** Get Wordle-style color for a cell */
  getCellColor(row: number, col: number): CellColor {
    return this.game.cellColors().get(`${row},${col}`) ?? 'grey';
  }

  /** All letter cells are always colored (green/yellow/grey) */
  isColoredCell(_row: number, _col: number): boolean {
    return true;
  }

  /** Green cells are locked — can't be selected or swapped */
  isLocked(row: number, col: number): boolean {
    return this.getCellColor(row, col) === 'green';
  }

  isHintSwapped(row: number, col: number): boolean {
    return this.game.hintSwappedCells().some(c => c.row === row && c.col === col);
  }

  getCellFly(row: number, col: number): { fromDx: number; fromDy: number } | null {
    return this.flyingCells().find(c => c.row === row && c.col === col) ?? null;
  }

  onCellClick(row: number, col: number): void {
    if (this.game.gameWon()) return;
    if (this.isLocked(row, col)) return;
    this.game.selectCell(row, col);
  }
}
