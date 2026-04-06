import { Component, OnInit, inject, signal, Output, EventEmitter } from '@angular/core';
import { CoinService } from '../core/services/coin.service';

export interface LevelNode {
  level:      number;
  x:          number;   // SVG/CSS percentage 0–100
  y:          number;   // SVG/CSS percentage 0–100 (from top of map body)
  difficulty: 'easy' | 'medium' | 'hard' | 'expert';
  isBoss:     boolean;
}

const LEVEL_KEY         = 'fjalekryq_level';
const PLAYING_LEVEL_KEY = 'fjalekryq_playing_level';
const STARS_KEY_PREFIX  = 'fjalekryq_stars_';

// Winding path: center → left → right → left → right → center → left → right → center → center(boss)
const NODES: LevelNode[] = [
  { level: 1,  x: 50, y: 92, difficulty: 'easy',   isBoss: false },
  { level: 2,  x: 21, y: 82, difficulty: 'easy',   isBoss: false },
  { level: 3,  x: 77, y: 72, difficulty: 'easy',   isBoss: false },
  { level: 4,  x: 21, y: 62, difficulty: 'medium', isBoss: false },
  { level: 5,  x: 77, y: 52, difficulty: 'medium', isBoss: false },
  { level: 6,  x: 50, y: 42, difficulty: 'medium', isBoss: false },
  { level: 7,  x: 21, y: 33, difficulty: 'hard',   isBoss: false },
  { level: 8,  x: 77, y: 24, difficulty: 'hard',   isBoss: false },
  { level: 9,  x: 50, y: 15, difficulty: 'hard',   isBoss: false },
  { level: 10, x: 50, y: 5,  difficulty: 'expert', isBoss: true  },
];

@Component({
  selector: 'app-level-map',
  standalone: true,
  imports: [],
  templateUrl: './level-map.component.html',
  styleUrl:    './level-map.component.scss',
})
export class LevelMapComponent implements OnInit {
  @Output() back        = new EventEmitter<void>();
  @Output() startLevel  = new EventEmitter<number>();

  coinService  = inject(CoinService);
  currentLevel = signal(1);
  levelStars: Record<number, number> = {};
  readonly nodes    = NODES;
  readonly segments = NODES.slice(0, -1).map((n, i) => ({ from: n, to: NODES[i + 1] }));

  dailyReward = signal<{ amount: number; day: number } | null>(null);

  ngOnInit(): void {
    const v = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.currentLevel.set(isNaN(v) || v < 1 ? 1 : v);
    for (let level = 1; level <= 10; level++) {
      const s = parseInt(localStorage.getItem(`${STARS_KEY_PREFIX}${level}`) ?? '0', 10);
      this.levelStars[level] = isNaN(s) ? 0 : s;
    }
    // Check and claim daily login reward
    const reward = this.coinService.claimDaily();
    if (reward) this.dailyReward.set(reward);
  }

  dismissDaily(): void { this.dailyReward.set(null); }

  getStars(level: number): number {
    return this.levelStars[level] ?? 0;
  }

  totalStars(): number {
    return Object.values(this.levelStars).reduce((sum, s) => sum + s, 0);
  }

  getState(level: number): 'completed' | 'current' | 'locked' {
    const cur = this.currentLevel();
    if (level < cur)  return 'completed';
    if (level === cur) return 'current';
    return 'locked';
  }

  /** CSS class for each path segment */
  segClass(from: number, to: number): string {
    const cur = this.currentLevel();
    if (to < cur)  return 'seg-done';
    if (from < cur && to === cur) return 'seg-active';
    return 'seg-locked';
  }

  completedCount(): number { return Math.max(0, this.currentLevel() - 1); }

  selectLevel(level: number): void {
    if (this.getState(level) === 'locked') return;
    // Set which level to play WITHOUT touching LEVEL_KEY (player's max progress)
    localStorage.setItem(PLAYING_LEVEL_KEY, String(level));
    this.startLevel.emit(level);
  }

  diffLabel(d: string): string {
    return ({ easy: 'E lehtë', medium: 'Mesatare', hard: 'E vështirë', expert: 'Ekspert' } as Record<string,string>)[d] ?? d;
  }

  /** Badge side: left-positioned nodes get right badge, right-positioned get left badge */
  badgeSide(x: number): 'right' | 'left' | 'below' {
    if (x < 40) return 'right';
    if (x > 60) return 'left';
    return 'below';
  }
}
