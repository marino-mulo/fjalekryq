import { Component, signal, computed, OnInit, OnDestroy } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

const LEVEL_KEY = 'fjalekryq_level';

const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split('');
const COLORS = ['green', 'yellow', 'grey'] as const;
const HERO_WORD = ['F', 'J', 'A', 'L', 'Ë', 'K', 'R', 'Y', 'Q'];

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
  private heroDestroyed = false;

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
    this.heroDestroyed = true;
    if (this.bgSwapTimer) clearInterval(this.bgSwapTimer);
    if (this.heroSwapTimer) {
      clearInterval(this.heroSwapTimer);
      clearTimeout(this.heroSwapTimer as unknown as ReturnType<typeof setTimeout>);
    }
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
    const shuffled = [...HERO_WORD].sort(() => Math.random() - 0.5);
    return shuffled.map((letter, i) => ({
      id: i,
      letter,
      color: Math.random() < 0.5 ? 'yellow' : 'grey',
      animKey: 0,
    }));
  }

  private startHeroSwaps(): void {
    this.runHeroCycle();
  }

  private async runHeroCycle(): Promise<void> {
    const delay = (ms: number) => new Promise<void>(res => {
      this.heroSwapTimer = setTimeout(res, ms) as unknown as ReturnType<typeof setInterval>;
    });

    while (!this.heroDestroyed) {
      // Scramble: reset all tiles to random letters, yellow/grey
      const scrambled = [...HERO_WORD].sort(() => Math.random() - 0.5);
      const baseKey = Date.now();
      this.heroTiles.set(scrambled.map((letter, i) => ({
        id: i,
        letter,
        color: Math.random() < 0.5 ? 'yellow' : 'grey' as 'yellow' | 'grey',
        animKey: baseKey + i,
      })));

      await delay(600);
      if (this.heroDestroyed) return;

      // Solve one by one in random order
      const solveOrder = [...Array(9).keys()].sort(() => Math.random() - 0.5);
      for (const pos of solveOrder) {
        if (this.heroDestroyed) return;
        const solveKey = Date.now();
        this.heroTiles.update(tiles => tiles.map((t, idx) => {
          if (idx !== pos) return t;
          return { ...t, letter: HERO_WORD[pos], color: 'green', animKey: solveKey };
        }));
        await delay(320);
        if (this.heroDestroyed) return;
      }

      // Pause fully solved
      await delay(2200);
    }
  }
}
