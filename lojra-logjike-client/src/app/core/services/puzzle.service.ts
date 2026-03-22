import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Wordle7Puzzle } from '../models/wordle7-puzzle.model';

@Injectable({ providedIn: 'root' })
export class PuzzleService {
  private http = inject(HttpClient);

  getWordle7ByDay(dayIndex: number): Observable<Wordle7Puzzle> {
    return this.http.get<Wordle7Puzzle>(`/api/puzzles/wordle7/${dayIndex}`);
  }
}
