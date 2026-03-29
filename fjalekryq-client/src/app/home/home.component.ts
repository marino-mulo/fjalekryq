import { Component, signal, computed, OnInit, OnDestroy } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

const LEVEL_KEY = 'fjalekryq_level';

const BG_LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split('');
const BG_COLORS = ['green', 'yellow', 'grey'] as const;

export interface BgTile {
  id: number;
  letter: string;
  x: number;    // left %
  y: number;    // top %
  color: 'green' | 'yellow' | 'grey';
  delay: number; // float animation-delay in seconds
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

  private swapTimer: ReturnType<typeof setInterval> | null = null;

  readonly difficultyKey = computed(() => {
    const l = this.level();
    if (l <= 100) return 'easy';
    if (l <= 300) return 'medium';
    if (l <= 500) return 'hard';
    return 'extreme';
  });

  readonly difficultyLabel = computed(() => {
    switch (this.difficultyKey()) {
      case 'easy':    return 'i lehtë';
      case 'medium':  return 'mesatar';
      case 'hard':    return 'i vështirë';
      default:        return 'shumë i vështirë';
    }
  });

  ngOnInit(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.bgTiles.set(this.createBgTiles());
    this.startBgSwaps();
  }

  ngOnDestroy(): void {
    if (this.swapTimer) clearInterval(this.swapTimer);
  }

  startGame(): void {
    this.showGame.set(true);
  }

  backToMenu(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.showGame.set(false);
  }

  private createBgTiles(): BgTile[] {
    const tiles: BgTile[] = [];
    // 3 rows × 6 cols = 18 tiles, spread across screen with jitter
    for (let i = 0; i < 18; i++) {
      const col = i % 6;
      const row = Math.floor(i / 6);
      tiles.push({
        id: i,
        letter: BG_LETTERS[Math.floor(Math.random() * BG_LETTERS.length)],
        x: 4 + col * 15.5 + (Math.random() - 0.5) * 8,
        y: 5 + row * 30 + (Math.random() - 0.5) * 12,
        color: BG_COLORS[i % 3],
        delay: Math.random() * 4,
      });
    }
    return tiles;
  }

  private startBgSwaps(): void {
    this.swapTimer = setInterval(() => {
      const tiles = this.bgTiles();
      const i = Math.floor(Math.random() * tiles.length);
      let j = Math.floor(Math.random() * (tiles.length - 1));
      if (j >= i) j++;

      const updated = tiles.map((t, idx) => {
        if (idx === i) return { ...t, x: tiles[j].x, y: tiles[j].y };
        if (idx === j) return { ...t, x: tiles[i].x, y: tiles[i].y };
        return t;
      });
      this.bgTiles.set(updated);
    }, 1200);
  }
}
