import { Component, signal, OnInit } from '@angular/core';
import { RouterOutlet } from '@angular/router';

const SP_LETTERS = 'ABCDEFGHJKLMNPRSTUVWXYZ'.split('');
const SP_COLORS  = ['g', 'y', 'd', 'o', 'r', 'b'] as const;

interface SpTile { id: number; letter: string; left: string; top: string; color: string; delay: string; }

@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App implements OnInit {
  showSplash    = signal(true);
  splashFading  = signal(false);
  splashTiles   = this.buildSplashTiles();

  private buildSplashTiles(): SpTile[] {
    const rows = [5, 24, 44, 64, 82];
    const tiles: SpTile[] = [];
    for (let r = 0; r < rows.length; r++) {
      for (let c = 0; c < 6; c++) {
        const i = r * 6 + c;
        tiles.push({
          id: i,
          letter: SP_LETTERS[Math.floor(Math.random() * SP_LETTERS.length)],
          left: `${(4 + c * 15.5 + (Math.random() - 0.5) * 6).toFixed(1)}vw`,
          top:  `${(rows[r]  + (Math.random() - 0.5) * 8).toFixed(1)}vh`,
          color: SP_COLORS[i % 3],
          delay: `${(Math.random() * 3).toFixed(2)}s`,
        });
      }
    }
    return tiles;
  }

  ngOnInit(): void {
    setTimeout(() => {
      this.splashFading.set(true);
      setTimeout(() => this.showSplash.set(false), 450);
    }, 2000);
  }
}
