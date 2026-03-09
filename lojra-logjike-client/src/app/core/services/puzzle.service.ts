import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ZipPuzzle } from '../models/zip-puzzle.model';
import { QueensPuzzle } from '../models/queens-puzzle.model';
import { Wordle7Puzzle } from '../models/wordle7-puzzle.model';
import { TangoPuzzle } from '../models/tango-puzzle.model';
import { StarsPuzzle } from '../models/stars-puzzle.model';
import { SnakePuzzle } from '../models/snake-puzzle.model';

@Injectable({ providedIn: 'root' })
export class PuzzleService {
  private http = inject(HttpClient);

  getZipToday(): Observable<ZipPuzzle> {
    return this.http.get<ZipPuzzle>('/api/puzzles/zip/today');
  }

  getZipByDay(dayIndex: number): Observable<ZipPuzzle> {
    return this.http.get<ZipPuzzle>(`/api/puzzles/zip/${dayIndex}`);
  }

  getQueensToday(): Observable<QueensPuzzle> {
    return this.http.get<QueensPuzzle>('/api/puzzles/queens/today');
  }

  getQueensByDay(dayIndex: number): Observable<QueensPuzzle> {
    return this.http.get<QueensPuzzle>(`/api/puzzles/queens/${dayIndex}`);
  }

  getWordle7ByDay(dayIndex: number): Observable<Wordle7Puzzle> {
    return this.http.get<Wordle7Puzzle>(`/api/puzzles/wordle7/${dayIndex}`);
  }

  getTangoToday(): Observable<TangoPuzzle> {
    return this.http.get<TangoPuzzle>('/api/puzzles/tango/today');
  }

  getTangoByDay(dayIndex: number): Observable<TangoPuzzle> {
    return this.http.get<TangoPuzzle>(`/api/puzzles/tango/${dayIndex}`);
  }

  getStarsToday(): Observable<StarsPuzzle> {
    return this.http.get<StarsPuzzle>('/api/puzzles/stars/today');
  }

  getStarsByDay(dayIndex: number): Observable<StarsPuzzle> {
    return this.http.get<StarsPuzzle>(`/api/puzzles/stars/${dayIndex}`);
  }

  getSnakeToday(): Observable<SnakePuzzle> {
    return this.http.get<SnakePuzzle>('/api/puzzles/snake/today');
  }

  getSnakeByDay(dayIndex: number): Observable<SnakePuzzle> {
    return this.http.get<SnakePuzzle>(`/api/puzzles/snake/${dayIndex}`);
  }
}
