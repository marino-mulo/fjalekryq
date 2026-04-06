import { Component, signal, inject, OnInit, OnDestroy } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';
import { LevelMapComponent } from '../level-map/level-map.component';
import { SettingsModalComponent } from '../shared/settings-modal/settings-modal.component';
import { CoinService, DAILY_REWARDS } from '../core/services/coin.service';

const LEVEL_KEY = 'fjalekryq_level';

const LETTERS = 'ABCÇDEHIMNOPRSTUVXZ'.split('');
const COLORS = ['gold', 'lime', 'grey'] as const;

interface BgTile {
  id: number;
  letter: string;
  x: number;
  y: number;
  color: 'gold' | 'lime' | 'grey';
  delay: number;
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [Wordle7Component, LevelMapComponent, SettingsModalComponent],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent implements OnInit, OnDestroy {
  coinService  = inject(CoinService);

  showGame     = signal(false);
  showLevelMap = signal(false);
  level        = signal(1);
  bgTiles      = signal<BgTile[]>([]);

  showSettings    = signal(false);
  showDailyModal  = signal(false);
  dailyAvailable  = signal(false);   // whether today's reward is unclaimed
  claimedReward   = signal<{ amount: number; day: number } | null>(null);

  readonly DAILY_REWARDS = DAILY_REWARDS;

  private bgSwapTimer: ReturnType<typeof setInterval> | null = null;

  ngOnInit(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.bgTiles.set(this.createBgTiles());
    this.startBgSwaps();
    this.dailyAvailable.set(this.coinService.peekDaily() !== null);
  }

  ngOnDestroy(): void {
    if (this.bgSwapTimer) clearInterval(this.bgSwapTimer);
  }

  startGame():    void { this.showLevelMap.set(true); }

  startTutorial(): void {
    localStorage.setItem('fjalekryq_force_tutorial', 'true');
    this.showGame.set(true);
  }

  startFromLevel(level: number): void {
    this.level.set(level);
    this.showGame.set(true);
  }

  backToHome(): void {
    this.showLevelMap.set(false);
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    // Refresh daily availability when returning
    this.dailyAvailable.set(this.coinService.peekDaily() !== null);
  }

  backToMenu(): void {
    const saved = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.level.set(isNaN(saved) || saved < 1 ? 1 : saved);
    this.showGame.set(false);
    this.showLevelMap.set(true);
  }

  openSettings():   void { this.showSettings.set(true); }
  closeSettings():  void { this.showSettings.set(false); }

  openDailyModal(): void { this.showDailyModal.set(true); }
  closeDailyModal(): void { this.showDailyModal.set(false); }

  claimTodayReward(): void {
    const result = this.coinService.claimDaily();
    if (result) {
      this.claimedReward.set(result);
      this.dailyAvailable.set(false);
    }
  }

  /** Day index (0-based) for streak display */
  get currentDay(): number { return this.coinService.currentStreakDay(); }

  private createBgTiles(): BgTile[] {
    const tiles: BgTile[] = [];
    // 3 rows × 5 cols = 15 tiles, starting below the header (~18%)
    const rows = [22, 48, 74];
    for (let r = 0; r < rows.length; r++) {
      for (let c = 0; c < 5; c++) {
        const i = r * 5 + c;
        tiles.push({
          id: i,
          letter: LETTERS[Math.floor(Math.random() * LETTERS.length)],
          x: 6 + c * 20 + (Math.random() - 0.5) * 8,
          y: rows[r] + (Math.random() - 0.5) * 10,
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
