import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Wordle7Puzzle } from '../models/wordle7-puzzle.model';

@Injectable({ providedIn: 'root' })
export class PuzzleService {
  private http = inject(HttpClient);

  getRandomWordle7(excludeHash?: string): Observable<Wordle7Puzzle> {
    let url = '/api/puzzles/wordle7/random';
    if (excludeHash) {
      url += `?excludeHash=${encodeURIComponent(excludeHash)}`;
    }
    return this.http.get<Wordle7Puzzle>(url);
  }
}
