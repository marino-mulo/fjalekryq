import { Component, signal, OnInit } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App implements OnInit {
  showSplash = signal(true);
  splashFading = signal(false);

  ngOnInit(): void {
    setTimeout(() => {
      this.splashFading.set(true);
      setTimeout(() => this.showSplash.set(false), 400);
    }, 2000);
  }
}
