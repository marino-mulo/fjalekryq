import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./home/home.component').then(m => m.HomeComponent)
  },
  { path: 'games/wordle-7x7', redirectTo: '', pathMatch: 'full' },
  { path: '**', redirectTo: '' }
];
