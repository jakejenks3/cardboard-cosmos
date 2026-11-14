// A "goal" is any unlock condition that can also report how close you are.
// Achievements, gear and pets are all expressed as goals so the UI can show
// progress bars and surface whatever is nearest to completion.

import type { PlayerState } from './state';

export type ProgressUnit = 'count' | 'kg' | 'm' | 'elev' | 'level' | 'grade' | 'weeks' | 'xp' | 'min' | 'ratio';

export interface Progress {
  cur: number;
  target: number;
  unit: ProgressUnit;
}

export interface Goal {
  check: (s: PlayerState) => boolean;
  progress?: (s: PlayerState) => Progress;
}

/** Goal met when `get(state) >= target`. */
export function atLeast(get: (s: PlayerState) => number, target: number, unit: ProgressUnit = 'count'): Required<Goal> {
  return {
    check: (s) => get(s) >= target,
    progress: (s) => ({ cur: get(s), target, unit }),
  };
}

/** 0..1 completion. Grades start at VB (-1), so shift them to be positive. */
export function progressRatio(p: Progress): number {
  if (p.unit === 'grade') return Math.max(0, Math.min(1, (p.cur + 2) / (p.target + 2)));
  if (p.target <= 0) return 1;
  return Math.max(0, Math.min(1, p.cur / p.target));
}
