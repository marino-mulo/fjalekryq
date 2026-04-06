import { Component, OnInit, AfterViewInit, inject, signal, Output, EventEmitter, computed, ElementRef, ViewChild } from '@angular/core';
import { CoinService } from '../core/services/coin.service';

export interface LevelNode {
  level:      number;
  letter:     string;
  difficulty: 'easy' | 'medium' | 'hard' | 'expert';
  isBoss:     boolean;
  col:        0 | 1 | 2;  // left | center | right
}

const LEVEL_KEY         = 'fjalekryq_level';
const PLAYING_LEVEL_KEY = 'fjalekryq_playing_level';
const STARS_KEY_PREFIX  = 'fjalekryq_stars_';
const TOTAL_LEVELS      = 500;
const VISIBLE_LOCKED    = 5;

const ALBANIAN_LETTERS = 'ABCDEFGHJKLMNOPRSTUVXZÇË'.split('');
// zigzag column pattern: left, center, right, center, left ...
const COL_PATTERN: (0 | 1 | 2)[] = [0, 1, 2, 1];

function difficultyFor(level: number): 'easy' | 'medium' | 'hard' | 'expert' {
  if (level <= 20)  return 'easy';
  if (level <= 60)  return 'medium';
  if (level <= 120) return 'hard';
  return 'expert';
}

function generateNodes(): LevelNode[] {
  return Array.from({ length: TOTAL_LEVELS }, (_, i) => {
    const level = i + 1;
    return {
      level,
      letter: ALBANIAN_LETTERS[i % ALBANIAN_LETTERS.length],
      difficulty: difficultyFor(level),
      isBoss: level % 10 === 0,
      col: COL_PATTERN[i % COL_PATTERN.length],
    };
  });
}

const ALL_NODES = generateNodes();

@Component({
  selector: 'app-level-map',
  standalone: true,
  imports: [],
  templateUrl: './level-map.component.html',
  styleUrl:    './level-map.component.scss',
})
export class LevelMapComponent implements OnInit, AfterViewInit {
  @Output() back        = new EventEmitter<void>();
  @Output() startLevel  = new EventEmitter<number>();
  @ViewChild('mapBody') mapBodyRef!: ElementRef<HTMLElement>;

  coinService   = inject(CoinService);
  currentLevel  = signal(1);
  levelStars: Record<number, number> = {};

  ngOnInit(): void {
    const v = parseInt(localStorage.getItem(LEVEL_KEY) ?? '1', 10);
    this.currentLevel.set(isNaN(v) || v < 1 ? 1 : v);
    for (let level = 1; level <= TOTAL_LEVELS; level++) {
      const s = parseInt(localStorage.getItem(`${STARS_KEY_PREFIX}${level}`) ?? '0', 10);
      this.levelStars[level] = isNaN(s) ? 0 : s;
    }
  }

  ngAfterViewInit(): void {
    // Scroll so the current level node is visible (centred in view)
    setTimeout(() => {
      const el = this.mapBodyRef?.nativeElement?.querySelector('.tile-current');
      if (el) {
        el.scrollIntoView({ behavior: 'instant', block: 'center' });
      }
    }, 50);
  }

  /** Nodes visible in the map: all completed + current + next VISIBLE_LOCKED locked */
  readonly visibleNodes = computed((): LevelNode[] => {
    const cur = this.currentLevel();
    const lastVisible = Math.min(cur + VISIBLE_LOCKED, TOTAL_LEVELS);
    return ALL_NODES.slice(0, lastVisible);
  });

  readonly hiddenCount = computed((): number =>
    Math.max(0, TOTAL_LEVELS - (this.currentLevel() + VISIBLE_LOCKED))
  );

  getStars(level: number): number { return this.levelStars[level] ?? 0; }

  totalStars(): number {
    return Object.values(this.levelStars).reduce((sum, s) => sum + s, 0);
  }

  getState(level: number): 'completed' | 'current' | 'locked' {
    const cur = this.currentLevel();
    if (level < cur)  return 'completed';
    if (level === cur) return 'current';
    return 'locked';
  }

  selectLevel(level: number): void {
    if (this.getState(level) === 'locked') return;
    localStorage.setItem(PLAYING_LEVEL_KEY, String(level));
    this.startLevel.emit(level);
  }

  diffLabel(d: string): string {
    return ({ easy: 'E lehtë', medium: 'Mesatare', hard: 'E vështirë', expert: 'Ekspert' } as Record<string,string>)[d] ?? d;
  }

  diffColor(d: string): string {
    return ({ easy: '#4ADE80', medium: '#FCD34D', hard: '#FCA5A5', expert: '#E879F9' } as Record<string,string>)[d] ?? '#fff';
  }
}
