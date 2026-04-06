import { Injectable, signal } from '@angular/core';

const COINS_KEY      = 'fjalekryq_coins';
const LAST_LOGIN_KEY = 'fjalekryq_last_login';
const STREAK_KEY     = 'fjalekryq_login_streak';

const STARTING_COINS = 100;

export const HINT_COST     = 10;
export const SOLVE_COST    = 50;
export const DAILY_REWARDS = [20, 25, 30, 40, 50, 75, 100]; // day 1–7 of streak

@Injectable({ providedIn: 'root' })
export class CoinService {
  readonly coins = signal(0);

  constructor() {
    const stored = localStorage.getItem(COINS_KEY);
    if (stored === null) {
      this.coins.set(STARTING_COINS);
      this.save();
    } else {
      this.coins.set(Math.max(0, parseInt(stored, 10) || 0));
    }
  }

  canAfford(amount: number): boolean { return this.coins() >= amount; }

  add(amount: number): void {
    this.coins.update(v => v + amount);
    this.save();
  }

  spend(amount: number): boolean {
    if (!this.canAfford(amount)) return false;
    this.coins.update(v => v - amount);
    this.save();
    return true;
  }

  /** Check if today's reward is available without claiming it. */
  peekDaily(): { amount: number; day: number } | null {
    const today = new Date().toDateString();
    if (localStorage.getItem(LAST_LOGIN_KEY) === today) return null;

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const lastLogin = localStorage.getItem(LAST_LOGIN_KEY);
    const streak = parseInt(localStorage.getItem(STREAK_KEY) ?? '0', 10);
    const newStreak = lastLogin === yesterday.toDateString() ? (streak % 7) + 1 : 1;
    return { amount: DAILY_REWARDS[newStreak - 1], day: newStreak };
  }

  /** Current claimed streak day (1-7). */
  currentStreakDay(): number {
    return Math.max(1, parseInt(localStorage.getItem(STREAK_KEY) ?? '1', 10));
  }

  /** Claim today's reward. Returns reward info or null if already claimed. */
  claimDaily(): { amount: number; day: number } | null {
    const today = new Date().toDateString();
    const lastLogin = localStorage.getItem(LAST_LOGIN_KEY);
    if (lastLogin === today) return null;

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const streak = parseInt(localStorage.getItem(STREAK_KEY) ?? '0', 10);
    const newStreak = lastLogin === yesterday.toDateString() ? (streak % 7) + 1 : 1;

    try {
      localStorage.setItem(LAST_LOGIN_KEY, today);
      localStorage.setItem(STREAK_KEY, String(newStreak));
    } catch { /* ignore */ }

    const amount = DAILY_REWARDS[newStreak - 1];
    this.add(amount);
    return { amount, day: newStreak };
  }

  private save(): void {
    try { localStorage.setItem(COINS_KEY, String(this.coins())); } catch { /* ignore */ }
  }
}
