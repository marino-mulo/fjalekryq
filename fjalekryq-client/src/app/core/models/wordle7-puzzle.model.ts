export interface WordEntry {
  word: string;
  row: number;
  col: number;
  direction: 'horizontal' | 'vertical';
}

export interface Wordle7Puzzle {
  gridSize: number;
  solution: string[][];
  words: WordEntry[];
  hash: string;
  swapLimit: number;
}
