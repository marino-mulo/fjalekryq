import { Component, signal, computed, OnInit } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

const LEVEL_KEY = 'fjalekryq_level';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [Wordle7Component],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent implements OnInit {
  showGame = signal(false);
  level = signal(1);

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
  }

  startGame(): void {
    this.showGame.set(true);
  }

  backToMenu(): void {
    const next = this.level() + 1;
    this.level.set(next);
    localStorage.setItem(LEVEL_KEY, String(next));
    this.showGame.set(false);
  }
}
