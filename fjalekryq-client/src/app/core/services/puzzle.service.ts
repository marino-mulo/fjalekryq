import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Wordle7Puzzle } from '../models/wordle7-puzzle.model';

@Injectable({ providedIn: 'root' })
export class PuzzleService {
  private http = inject(HttpClient);

  getWordle7Level(level: number): Observable<Wordle7Puzzle> {
    return this.http.get<Wordle7Puzzle>(`/api/puzzles/wordle7/level/${level}`);
  }

  getRandomWordle7(excludeWords?: string[], difficulty?: string): Observable<Wordle7Puzzle> {
    let params = new HttpParams();
    if (excludeWords && excludeWords.length > 0) {
      params = params.set('excludeWords', excludeWords.join(','));
    }
    if (difficulty) {
      params = params.set('difficulty', difficulty);
    }
    return this.http.get<Wordle7Puzzle>('/api/puzzles/wordle7/random', { params });
  }
}
