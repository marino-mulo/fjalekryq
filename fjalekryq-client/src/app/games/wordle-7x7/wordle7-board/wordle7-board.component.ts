import { Component, Input, Output, EventEmitter, effect, signal } from '@angular/core';
import { Wordle7GameService, CellColor } from '../wordle7-game.service';

// Cell size lookup to keep total board around ~388px wide
const CELL_SIZE_MAP: Record<number, number> = { 5: 75, 6: 65, 7: 57, 8: 50, 9: 44, 10: 39, 11: 35, 12: 32, 13: 30 };
const FONT_SIZE_MAP: Record<number, number> = { 5: 32, 6: 28, 7: 24, 8: 21, 9: 18, 10: 16, 11: 14, 12: 13, 13: 12 };

@Component({
  selector: 'app-wordle7-board',
  standalone: true,
  imports: [],
  templateUrl: './wordle7-board.component.html',
  styleUrl: './wordle7-board.component.scss'
})
export class Wordle7BoardComponent {
  @Input({ required: true }) game!: Wordle7GameService;
  @Input() tutorialHighlight: { row: number; col: number }[] = [];
  @Input() disableSwap = false;
  @Output() win = new EventEmitter<void>();

  @Input() set introTrigger(val: number) {
    if (val > 0) this.playIntro();
  }

  private winEmitted = false;
  private previousWonState = false;

  readonly flyingCells = signal<Array<{ row: number; col: number; fromDx: number; fromDy: number }>>([]);
  private flyTimer: ReturnType<typeof setTimeout> | null = null;

  readonly introActive = signal(false);
  private introTimer: ReturnType<typeof setTimeout> | null = null;

  playIntro(): void {
    this.introActive.set(false);
    // Force reflow so animation restarts cleanly
    setTimeout(() => {
      this.introActive.set(true);
      if (this.introTimer) clearTimeout(this.introTimer);
      const size = this.gridSize;
      const total = size * size;
      const duration = 800 + total * 25; // ~2s for 7x7
      this.introTimer = setTimeout(() => {
        this.introActive.set(false);
        this.introTimer = null;
      }, duration + 100);
    }, 20);
  }

  /** Offset to translate cell FROM centre of board */
  getIntroDx(col: number): number {
    return this.svgWidth  / 2 - (this.cellX(col) + this.cellSize / 2);
  }
  getIntroDy(row: number): number {
    return this.svgHeight / 2 - (this.cellY(row) + this.cellSize / 2);
  }
  getIntroDelay(row: number, col: number): number {
    // Cells radiate outward from centre: cells closer to centre fly first
    const cx = (this.gridSize - 1) / 2;
    const dist = Math.sqrt((row - cx) ** 2 + (col - cx) ** 2);
    return Math.round(dist * 65);
  }

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

  isHighlighted(row: number, col: number): boolean {
    return this.tutorialHighlight.some(c => c.row === row && c.col === col);
  }

  getCellFly(row: number, col: number): { fromDx: number; fromDy: number } | null {
    return this.flyingCells().find(c => c.row === row && c.col === col) ?? null;
  }

  onCellClick(row: number, col: number): void {
    if (this.game.gameWon()) return;
    if (this.disableSwap) return;
    if (this.isLocked(row, col)) return;
    if (this.tutorialHighlight.length > 0 && !this.isHighlighted(row, col)) return;
    this.game.selectCell(row, col);
  }
}
