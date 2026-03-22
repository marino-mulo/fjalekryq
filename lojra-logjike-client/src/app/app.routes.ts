import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./home/home.component').then(m => m.HomeComponent)
  },
  {
    path: 'games/wordle-7x7',
    loadComponent: () => import('./games/wordle-7x7/wordle7.component').then(m => m.Wordle7Component)
  },
  {
    path: 'games/wordle-7x7/:day',
    loadComponent: () => import('./games/wordle-7x7/wordle7.component').then(m => m.Wordle7Component)
  },
  { path: '**', redirectTo: '' }
];
