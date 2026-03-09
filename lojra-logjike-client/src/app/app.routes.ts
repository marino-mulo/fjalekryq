import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./home/home.component').then(m => m.HomeComponent)
  },
  {
    path: 'games/zip',
    loadComponent: () => import('./games/zip/zip.component').then(m => m.ZipComponent)
  },
  {
    path: 'games/zip/:day',
    loadComponent: () => import('./games/zip/zip.component').then(m => m.ZipComponent)
  },
  {
    path: 'games/stars',
    loadComponent: () => import('./games/stars/stars.component').then(m => m.StarsComponent)
  },
  {
    path: 'games/stars/:day',
    loadComponent: () => import('./games/stars/stars.component').then(m => m.StarsComponent)
  },
  {
    path: 'games/queens',
    loadComponent: () => import('./games/queens/queens.component').then(m => m.QueensComponent)
  },
  {
    path: 'games/queens/:day',
    loadComponent: () => import('./games/queens/queens.component').then(m => m.QueensComponent)
  },
  {
    path: 'games/wordle-7x7',
    loadComponent: () => import('./games/wordle-7x7/wordle7.component').then(m => m.Wordle7Component)
  },
  {
    path: 'games/wordle-7x7/:day',
    loadComponent: () => import('./games/wordle-7x7/wordle7.component').then(m => m.Wordle7Component)
  },
  {
    path: 'games/tango',
    loadComponent: () => import('./games/tango/tango.component').then(m => m.TangoComponent)
  },
  {
    path: 'games/tango/:day',
    loadComponent: () => import('./games/tango/tango.component').then(m => m.TangoComponent)
  },
  {
    path: 'games/snake',
    loadComponent: () => import('./games/snake/snake.component').then(m => m.SnakeComponent)
  },
  {
    path: 'games/snake/:day',
    loadComponent: () => import('./games/snake/snake.component').then(m => m.SnakeComponent)
  },
  { path: '**', redirectTo: '' }
];
