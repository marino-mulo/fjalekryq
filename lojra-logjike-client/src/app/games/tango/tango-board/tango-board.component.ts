import { Component, Input, Output, EventEmitter, effect } from '@angular/core';
import { TangoGameService, EMPTY, SUN, MOON } from '../tango-game.service';
import { TangoConstraint } from '../../../core/models/tango-puzzle.model';

interface ConstraintDisplay {
  x: number;
  y: number;
  symbol: string; // '=' or '×'
}

@Component({
  selector: 'app-tango-board',
  standalone: true,
  imports: [],
  templateUrl: './tango-board.component.html',
  styleUrl: './tango-board.component.scss'
})
export class TangoBoardComponent {
  @Input({ required: true }) game!: TangoGameService;
  @Output() win = new EventEmitter<void>();

  private previousWonState = false;
  private winEmitted = false;

  readonly cellSize = 76;
  readonly size = 6;
  readonly symbolRadius = 18;

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

  get cells(): number[] { return Array.from({ length: this.size * this.size }, (_, i) => i); }
  get svgWidth(): number { return this.size * this.cellSize; }
  get svgHeight(): number { return this.size * this.cellSize; }

  cellRow(i: number): number { return Math.floor(i / this.size); }
  cellCol(i: number): number { return i % this.size; }
  cellX(i: number): number { return this.cellCol(i) * this.cellSize; }
  cellY(i: number): number { return this.cellRow(i) * this.cellSize; }
  cellCenterX(i: number): number { return this.cellX(i) + this.cellSize / 2; }
  cellCenterY(i: number): number { return this.cellY(i) + this.cellSize / 2; }

  isSun(i: number): boolean {
    return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === SUN;
  }

  isMoon(i: number): boolean {
    return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === MOON;
  }

  isEmpty(i: number): boolean {
    return this.game.board()[this.cellRow(i)]?.[this.cellCol(i)] === EMPTY;
  }

  isPrefilled(i: number): boolean {
    return this.game.isPrefilled(this.cellRow(i), this.cellCol(i));
  }

  onCellClick(i: number): void {
    this.game.toggleCell(this.cellRow(i), this.cellCol(i));
  }

  isHintCell(i: number): boolean {
    const cells = this.game.hintCells();
    if (cells.length === 0) return false;
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    return cells.some(cell => cell.row === r && cell.col === c);
  }

  isConflict(i: number): boolean {
    const cells = this.game.conflictCells();
    if (cells.length === 0) return false;
    const r = this.cellRow(i);
    const c = this.cellCol(i);
    return cells.some(cell => cell.row === r && cell.col === c);
  }

  // Grid lines
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

  // Moon as a crescent (two arcs: outer semicircle + flatter inner arc)
  moonPath(cx: number, cy: number): string {
    const R = this.symbolRadius;
    const innerR = R * 1.5;
    return `M ${cx},${cy - R} A ${R},${R} 0 0,0 ${cx},${cy + R} A ${innerR},${innerR} 0 0,1 ${cx},${cy - R}`;
  }

  winAnimDelay(i: number): number {
    const row = this.cellRow(i);
    const col = this.cellCol(i);
    // Diagonal wave: top-left starts first
    return (row + col) * 60;
  }

  // Constraint display positions — placed on the border between two cells
  get constraintDisplays(): ConstraintDisplay[] {
    const constraints = this.game.getConstraints();
    return constraints.map(ct => {
      const x1 = ct.c1 * this.cellSize + this.cellSize / 2;
      const y1 = ct.r1 * this.cellSize + this.cellSize / 2;
      const x2 = ct.c2 * this.cellSize + this.cellSize / 2;
      const y2 = ct.r2 * this.cellSize + this.cellSize / 2;
      return {
        x: (x1 + x2) / 2,
        y: (y1 + y2) / 2,
        symbol: ct.type === 'same' ? '=' : '×',
      };
    });
  }
}
