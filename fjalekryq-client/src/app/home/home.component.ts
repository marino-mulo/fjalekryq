import { Component, signal, computed, OnInit, OnDestroy } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

const LEVEL_KEY = 'fjalekryq_level';

const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split('');
const COLORS = ['green', 'yellow', 'grey'] as const;

interface BgTile {
  id: number;
  letter: string;
  x: number;
  y: number;
  color: 'green' | 'yellow' | 'grey';
  delay: number;
}

interface HeroTile {
  id: number;
  letter: string;
  color: 'green' | 'yellow' | 'grey';
  animKey: number;
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
  heroTiles = signal<HeroTile[]>([]);

  private bgSwapTimer: ReturnType<typeof setInterval> | null = null;
  private heroSwapTimer: ReturnType<typeof setInterval> | null = null;

  readonly difficultyKey = computed(() => {
    const l = this.level();
    if (l <= 100) return 'easy';
    if (l <= 300) return 'medium';
    if (l <= 500) return 'hard';
    return 'extreme';
  });

  ngOnInit(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.bgTiles.set(this.createBgTiles());
    this.heroTiles.set(this.createHeroTiles());
    this.startBgSwaps();
    this.startHeroSwaps();
  }

  ngOnDestroy(): void {
    if (this.bgSwapTimer) clearInterval(this.bgSwapTimer);
    if (this.heroSwapTimer) clearInterval(this.heroSwapTimer);
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
    for (let i = 0; i < 18; i++) {
      const col = i % 6;
      const row = Math.floor(i / 6);
      tiles.push({
        id: i,
        letter: LETTERS[Math.floor(Math.random() * LETTERS.length)],
        x: 4 + col * 15.5 + (Math.random() - 0.5) * 8,
        y: 5 + row * 30 + (Math.random() - 0.5) * 12,
        color: COLORS[i % 3],
        delay: Math.random() * 4,
      });
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

  private createHeroTiles(): HeroTile[] {
    return Array.from({ length: 16 }, (_, i) => ({
      id: i,
      letter: LETTERS[Math.floor(Math.random() * LETTERS.length)],
      color: COLORS[i % 3],
      animKey: 0,
    }));
  }

  private startHeroSwaps(): void {
    this.heroSwapTimer = setInterval(() => {
      const tiles = this.heroTiles();
      const i = Math.floor(Math.random() * tiles.length);
      let j = Math.floor(Math.random() * (tiles.length - 1));
      if (j >= i) j++;
      const newKey = Date.now();
      this.heroTiles.set(tiles.map((t, idx) => {
        if (idx === i) return { ...t, letter: tiles[j].letter, color: tiles[j].color, animKey: newKey };
        if (idx === j) return { ...t, letter: tiles[i].letter, color: tiles[i].color, animKey: newKey + 1 };
        return t;
      }));
    }, 900);
  }
}
