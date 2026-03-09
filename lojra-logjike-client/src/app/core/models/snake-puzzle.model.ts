export interface SnakePuzzle {
  size: number;
  rowClues: number[];
  colClues: number[];
  headRow: number;
  headCol: number;
  tailRow: number;
  tailCol: number;
  snakeLength: number;
  givens: number[][]; // [row, col, stepNumber]
  solution: number[][]; // 0=empty, 1..N=path order (1=head, N=tail)
  dayIndex: number;
  dayName: string;
}
