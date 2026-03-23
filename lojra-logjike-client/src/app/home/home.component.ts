import { Component } from '@angular/core';
import { Wordle7Component } from '../games/wordle-7x7/wordle7.component';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [Wordle7Component],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent {}
