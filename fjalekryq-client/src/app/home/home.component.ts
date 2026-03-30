import { Component, signal, OnInit, OnDestroy } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

const LEVEL_KEY = 'fjalekryq_level';

const LETTERS = 'ABCÇDEHIMNOPRSTUVXZ'.split('');
const COLORS = ['green', 'yellow', 'grey'] as const;

interface BgTile {
  id: number;
  letter: string;
  x: number;
  y: number;
  color: 'green' | 'yellow' | 'grey';
  delay: number;
}


@Component({
  selector: 'app-home',
  standalone: true,
  imports: [Wordle7Component],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent implements OnInit, OnDestroy {
  showGame = signal(false);
  level = signal(1);
  bgTiles = signal<BgTile[]>([]);

  private bgSwapTimer: ReturnType<typeof setInterval> | null = null;

  ngOnInit(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.bgTiles.set(this.createBgTiles());
    this.startBgSwaps();
  }

  ngOnDestroy(): void {
    if (this.bgSwapTimer) clearInterval(this.bgSwapTimer);
  }

  startGame(): void {
    this.showGame.set(true);
  }

  startTutorial(): void {
    localStorage.setItem('fjalekryq_force_tutorial', 'true');
    this.showGame.set(true);
  }

  backToMenu(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.showGame.set(false);
  }

  private createBgTiles(): BgTile[] {
    const tiles: BgTile[] = [];
    const rows = [5, 24, 44, 64, 82];
    for (let r = 0; r < rows.length; r++) {
      for (let c = 0; c < 6; c++) {
        const i = r * 6 + c;
        tiles.push({
          id: i,
          letter: LETTERS[Math.floor(Math.random() * LETTERS.length)],
          x: 4 + c * 15.5 + (Math.random() - 0.5) * 6,
          y: rows[r] + (Math.random() - 0.5) * 8,
          color: COLORS[i % 3],
          delay: Math.random() * 4,
        });
      }
    }
    return tiles;
  }

  private startBgSwaps(): void {
    this.bgSwapTimer = setInterval(() => {
      const tiles = this.bgTiles();
      const i = Math.floor(Math.random() * tiles.length);
      let j = Math.floor(Math.random() * (tiles.length - 1));
      if (j >= i) j++;
      this.bgTiles.set(tiles.map((t, idx) => {
        if (idx === i) return { ...t, x: tiles[j].x, y: tiles[j].y };
        if (idx === j) return { ...t, x: tiles[i].x, y: tiles[i].y };
        return t;
      }));
    }, 1200);
  }

}
